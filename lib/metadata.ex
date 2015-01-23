defmodule Kafka.Metadata do
  def new(broker_list, client_id) do
    Kafka.Connection.connect(broker_list, client_id)
    |> get(client_id)
  end

  defp _get_brokers({:ok, metadata}, _client_id, topic, partition) do
    {:ok, metadata, get_brokers_for_topic(metadata, %{}, topic, partition)}
  end

  defp _get_brokers({:error, reason}, _, _) do
    {:error, reason}
  end

  def get_brokers(metadata, client_id, topic, partition) do
    update(metadata, client_id)
    |> _get_brokers(client_id, topic, partition)
  end

  defp get_brokers_for_topic(metadata, map, topic, partition) do
    Enum.reduce(metadata.topics[topic][:partitions],
                map,
                fn({partition_id, partition_map}, acc) ->
                  if partition == partition_id || partition == :all do
                    broker = metadata.brokers[partition_map[:leader]]
                    if Map.has_key?(acc, broker) do
                      if Map.has_key?(acc[broker], topic) do
                        Map.put(acc, broker, Map.put(acc[broker], topic, acc[broker][topic] ++ [partition_id]))
                      else
                        Map.put(acc, broker, Map.put(acc[broker], topic, [partition_id]))
                      end
                    else
                      Map.put(acc, broker, Map.put(%{}, topic, [partition_id]))
                    end
                  else
                    acc
                  end
                end)
  end

  defp get({:ok, connection}, client_id) do
    Kafka.Connection.send(connection, create_request(connection.correlation_id, client_id))
    |> parse_response
  end

  defp get({:error, message}, _client_id) do
    {:error, "Error connecting to Kafka: #{message}", %{}}
  end

  def update(metadata, client_id) do
    if Kafka.Helper.get_timestamp - metadata.timestamp >= 5 * 60 do
      get({:ok, metadata.connection}, client_id)
    else
      {:ok, metadata}
    end
  end

  defp create_request(correlation_id, client_id) do
    << 3 :: 16, 0 :: 16, correlation_id :: 32, String.length(client_id) :: 16 >> <>
      client_id <> << 0 :: 32 >>
  end

  defp parse_response({:ok, connection, metadata}) do
    timestamp = Kafka.Helper.get_timestamp
    << _ :: 32, num_brokers :: 32, rest :: binary >> = metadata
    {broker_map, rest} = parse_broker_list(%{}, num_brokers, rest)
    << num_topic_metadata :: 32, rest :: binary >> = rest
    {topic_map, _} = parse_topic_metadata(%{}, num_topic_metadata, rest)
    {:ok, %{brokers: broker_map, topics: topic_map, timestamp: timestamp, connection: connection}}
  end

  defp parse_broker_list(map, 0, rest) do
    {map, rest}
  end

  defp parse_broker_list(map, num_brokers, data) do
    << node_id :: 32, host_len :: 16, host :: size(host_len)-binary, port :: 32, rest :: binary >> = data
    {broker_map, rest} = parse_broker_list(map, num_brokers-1, rest)
    {Map.put(broker_map, node_id, %{host: host, port: port, socket: nil}), rest}
  end

  defp parse_topic_metadata(map, 0, rest) do
    {map, rest}
  end

  defp parse_topic_metadata(map, num_topic_metadata, data) do
    << error_code :: 16, topic_len :: 16, topic :: size(topic_len)-binary, num_partitions :: 32, rest :: binary >> = data
    {partition_map, rest} = parse_partition_metadata(%{}, num_partitions, rest)
    {topic_map, rest} = parse_topic_metadata(map, num_topic_metadata-1, rest)
    {Map.put(topic_map, topic, error_code: error_code, partitions: partition_map), rest}
  end

  defp parse_partition_metadata(map, 0, rest) do
    {map, rest}
  end

  defp parse_partition_metadata(map, num_partitions, data) do
    << error_code :: 16, id :: 32, leader :: 32, num_replicas :: 32, rest :: binary >> = data
    {replicas, rest} = parse_int32_array(num_replicas, rest)
    << num_isr :: 32, rest :: binary >> = rest
    {isrs, rest} = parse_int32_array(num_isr, rest)
    {partition_map, rest} = parse_partition_metadata(map, num_partitions-1, rest)
    {Map.put(partition_map, id, %{error_code: error_code, leader: leader, replicas: replicas, isrs: isrs}), rest}
  end

  defp parse_int32_array(0, rest) do
    {[], rest}
  end

  defp parse_int32_array(num, data) do
    << value :: 32, rest :: binary >> = data
    {values, rest} = parse_int32_array(num-1, rest)
    {[value | values], rest}
  end
end