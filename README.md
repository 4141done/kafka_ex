KafkaEx
========

Kafka client for Elixir/Erlang.

Usage
-----

### Configuration

In your config/config.exs add the list of kafka brokers as below:
```elixir
config KafkaEx,
  brokers: [{HOST, PORT}]
```

Alternatively from iex:
```elixir
iex> Application.put_env(KafkaEx, :brokers, [{"localhost", 9092}, {"localhost", 9093}])
:ok
```

### Create KafkaEx worker
```elixir
iex> KafkaEx.create_worker(:pr)
{:ok, #PID<0.171.0>}
```

### Retrieve kafka metadata
For all metadata

```elixir
iex> KafkaEx.metadata
%{brokers: %{1 => {"localhost", 9092}},
  topics: %{"foo" => %{error_code: 0,
      partitions: %{0 => %{error_code: 0, isrs: [1], leader: 1, replicas: [1]}}},
      "bar" => %{error_code: 0,
      partitions: %{0 => %{error_code: 0, isrs: [1], leader: 1, replicas: [1]}}}}}
```

For a specific topic

```elixir
iex> KafkaEx.metadata("foo")
%{brokers: %{1 => {"localhost", 9092}},
  topics: %{"foo" => %{error_code: 0,
      partitions: %{0 => %{error_code: 0, isrs: [1], leader: 1, replicas: [1]}}}}}
```

### Retrieve the latest offset

```elixir
iex> KafkaEx.latest_offset("foo", 0) # where 0 is the partition
{:ok, %{"foo" => %{0 => %{error_code: 0, offsets: [16]}}}}
```

### Retrieve the earliest offset

```elixir
iex> KafkaEx.earliest_offset("foo", 0) # where 0 is the partition
{:ok, %{"foo" => %{0 => %{error_code: 0, offsets: [0]}}}}
```

### Fetch kafka logs

```elixir
iex> KafkaEx.fetch("foo", 0, 5) # where 0 is the partition and 5 is the offset we want to start fetching from
{:ok,
 %{"foo" => %{0 => %{error_code: 0, hw_mark_offset: 133,
       message_set: [%{attributes: 0, crc: 4264455069, key: nil, offset: 5,
          value: "hey"},
        %{attributes: 0, crc: 4264455069, key: nil, offset: 6, value: "hey"},
...]}}}}
```

### Produce kafka logs

```elixir
iex> KafkaEx.produce("foo", 0, "hey") # where "foo" is the topic and "hey" is the message
:ok
```

### Stream kafka logs

```elixir
iex> KafkaEx.create_worker([{"localhost", 9092}], :stream)
{:ok, #PID<0.196.0>}
iex> KafkaEx.produce("foo", 0, "hey", :stream)
:ok
iex> KafkaEx.produce("foo", 0, "hi", :stream)
:ok
iex> KafkaEx.stream("foo", 0) |> iex> Enum.take(2)
[%{attributes: 0, crc: 4264455069, key: nil, offset: 0, value: "hey"},
 %{attributes: 0, crc: 4251893211, key: nil, offset: 1, value: "hi"}]
```


### Test

#### Unit tests
```
mix test --no-start
```

#### Integration tests
Add the broker config to `config/config.exs` and run:
```
mix test --only integration
```

### Static analysis

```
mix dialyze --unmatched-returns --error-handling --race-conditions --underspecs
```

### Contributing
Please see [CONTRIBUTING.md](CONTRIBUTING.md)
