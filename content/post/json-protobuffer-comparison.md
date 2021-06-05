---
title: Protocol Buffer x JSON para serialização de dados
date: 2020-06-05T12:00:00-03:00
tags:
  - Protocol Buffer
  - JSON
weight: 1
---

Atualmente o formato [JSON](https://en.wikipedia.org/wiki/JSON) é um dos formatos mais usados para serialização/deserialização de dados por ter suporte nativo na maioria dos navegadores, ser muito conhecido e ter uma grande variedade de bibliotecas nas mais diversas linguagens. Além disso, por ser em formato texto é legível para humanos. 

Porém, há alguns problemas: não faz distinção entre inteiro e float e não especifica precisão. Isso pode ser um problema quando se está lidando com números grandes. Por exemplo, inteiros maiores que 2ˆ53 não podem ser exatamente representados em um número de ponto flutuante de precisão dupla [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754), fazendo com que esses números sejam parseados de forma incorreta. Além disso, não suporta strings binárias (sequência de caracteres sem encoding)[1].

Existem outros formatos/ferramentas de serialização/deserialização como XML, Apache Thrift, Protocol Buffers entre outros, que podem ser alternativas viáveis para várias aplicações. O objetivo deste post não é mostrar como usar a ferramenta, e sim focar na comparação de Protocol Buffer com JSON: performance na operação de serialização/deserialização, tamanho do dado serializado e formas de uso. O teste será baseado na linguagem Go.

## Protocol Buffer
Protocol Buffer é um mecanismo criado pela Google para serialização de dados estruturados, onde é agnóstico de linguagem e plataforma. É baseado em schema, tem formato binário, e um gerador de código para várias linguagens, como: C++, C#, Dart, Go, Java, Kotlin, Python, Ruby, Objective C, Javascript, PHP, [entre outras](https://github.com/protocolbuffers/protobuf/blob/master/docs/third_party.md). 

Exemplo de schema:

```
message Person {
  required string name = 1;
  required int32 id = 2;
  optional string email = 3;
}
```

Para mais detalhes sobre a ferramenta, como usar, referências e exemplos visite a página https://developers.google.com/protocol-buffers. 

## Como foi feito a comparação

Criei uma [API simples em Go](https://github.com/michelaquino/protobuffer-json-comparison) onde os dados são salvos em uma instância do Redis, ambos rodando via Docker. Há endpoints `POST` (salvar um dado no Redis) e `GET` (bucar o dado no Redis e devolver):

- `/proto`: serializa/deserializa os dados em ProtocolBuffer baseado no [schema definido](https://github.com/michelaquino/protobuffer-json-comparison/tree/main/proto)
- `/json`: serializa/deserializa os dados em JSON
- `/protojson`: serializa/deserializa os dados em JSON usando o [schema definido em ProtocolBuffer](https://github.com/michelaquino/protobuffer-json-comparison/tree/main/proto)

Para fazer a comparação foi usado o mesmo dado, que está definido *hardcoded* [aqui](https://github.com/michelaquino/protobuffer-json-comparison/blob/main/marshalUnmarshal/data.go).

Os seguintes testes foram feitos:
- [Testes de benchmark do Go](https://golang.org/pkg/testing/#hdr-Benchmarks), onde são comparados quantas operações de serialização e deserialização são feitos por segundo
- Testes usando a ferramenta [WRK](https://github.com/wg/wrk) para fazer requests simultâneos nas rotas e comparar quantos requests por segundo a API suporta
- Avaliação do tamanho e formato do dado serializado no Redis

Todos os testes foram feitos usando um macbook com as seguintes especificações:
```
MacBook Pro
Processador: 2 GHz Quad-Core Intel Core i5
Memória: 16 GB 3733 MHz LPDDR4X
```

## Resultados

### Benchmark funções
A primeira coluna refere ao nome da função de teste, a segunda à quantidade de operações realizadas no teste e a terceira quantos nanosegundos foram gastos por operação.

- Serialização
```
goos: darwin
goarch: amd64
cpu: Intel(R) Core(TM) i5-1038NG7 CPU @ 2.00GHz

BenchmarkSerializeJSON-8                           42920             28149 ns/op
BenchmarkSerializeProtocolBuffer-8                 44228             27277 ns/op
BenchmarkSerializeProtocolBufferAsJSON-8           30870             40263 ns/op
```

- Deserialização
```
goos: darwin
goarch: amd64
cpu: Intel(R) Core(TM) i5-1038NG7 CPU @ 2.00GHz

BenchmarkDeserializeJSON-8                        110302             10970 ns/op
BenchmarkDeserializeProtocolBuffer-8              562112              2198 ns/op
BenchmarkDeserializeProtocolBufferAsJSON-8         69072             18385 ns/op
```

### Benchmark requests
#### POST

##### ProtocolBuffer
```
Running 10s test @ http://localhost:8888/proto
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    36.22ms   24.47ms 249.28ms   71.60%
    Req/Sec    29.12     13.40   161.00     76.51%
  29326 requests in 10.10s, 2.10MB read
Requests/sec:   2903.42
Transfer/sec:    212.65KB
```

##### JSON
```
Running 10s test @ http://localhost:8888/json
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    79.52ms  169.71ms   1.09s    93.17%
    Req/Sec    29.16     13.22   110.00     76.06%
  26869 requests in 10.09s, 1.92MB read
Requests/sec:   2661.85
Transfer/sec:    194.96KB
```

##### ProtocolBuffer como JSON
```
Running 10s test @ http://localhost:8888/protojson
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    40.33ms   27.15ms 241.85ms   70.52%
    Req/Sec    26.16     12.45   100.00     63.87%
  26330 requests in 10.10s, 1.88MB read
Requests/sec:   2607.63
Transfer/sec:    190.99KB
```

#### GET

##### ProtocolBuffer
```
Running 10s test @ http://localhost:8888/proto
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    25.33ms   14.87ms 143.20ms   72.99%
    Req/Sec    40.86     14.23   171.00     74.51%
  41078 requests in 10.10s, 13.59MB read
Requests/sec:   4067.33
Transfer/sec:      1.35MB
```

##### JSON
```
Running 10s test @ http://localhost:8888/json
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    26.13ms   15.08ms 135.74ms   71.77%
    Req/Sec    39.44     13.27   171.00     77.17%
  39667 requests in 10.10s, 22.66MB read
Requests/sec:   3927.37
Transfer/sec:      2.24MB
```

##### ProtocolBuffer como JSON
```
Running 10s test @ http://localhost:8888/protojson
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    27.08ms   15.91ms 156.36ms   73.76%
    Req/Sec    38.24     13.48   141.00     75.38%
  38499 requests in 10.09s, 22.65MB read
Requests/sec:   3813.99
Transfer/sec:      2.24MB
```


### Tamanho e formato do dado serializado no Redis
#### ProtocolBuffer
O tamanho do dado é em bytes.

```
MEMORY USAGE "address-PROTO"
(integer) 312
```

```
GET "address-PROTO"
"\np\n\bname 101\x12$2ed0bb14-6710-42a8-931f-69d7ae3d0a8e\x1a\temail 384\"\n\n\b15-99-18\"\x0b\n\a11-7-70\x10\x01\"\x0c\n\b18-64-85\x10\x02*\x0c\b\xfc\xf0\xc9\x85\x06\x10\xc4\xa7\xa8\x9e\x01\nq\n\bname 660\x12$25a4b343-98da-42b8-85fa-be3e6ea0e0d2\x1a\temail 410\"\n\n\b20-50-93\"\x0c\n\b88-56-96\x10\x01\"\x0c\n\b50-78-43\x10\x02*\x0c\b\xfc\xf0\xc9\x85\x06\x10\xb8\xc7\xaa\x9e\x01"
```

#### JSON
```
MEMORY USAGE "address-JSON"
(integer) 568
```

```
GET "address-JSON"
"{\"people\":[{\"name\":\"name 992\",\"id\":\"59ed3f8a-ef20-48c6-a392-52663360658c\",\"email\":\"email 122\",\"phones\":[{\"number\":\"19-31-88\"},{\"number\":\"80-46-55\",\"type\":1},{\"number\":\"33-58-89\",\"type\":2}],\"last_updated\":{\"seconds\":1622308984,\"nanos\":121239469}},{\"name\":\"name 553\",\"id\":\"0287e61b-5f63-45a9-8dff-9ebae231f31b\",\"email\":\"email 783\",\"phones\":[{\"number\":\"82-23-38\"},{\"number\":\"91-36-36\",\"type\":1},{\"number\":\"62-58-71\",\"type\":2}],\"last_updated\":{\"seconds\":1622308984,\"nanos\":121285583}}]}"
```

#### Protocol Buffer como JSON
```
MEMORY USAGE "address-PROTO-JSON"
(integer) 576
```

```
GET "address-PROTO-JSON"
"{\"people\":[{\"name\":\"name 284\",\"id\":\"6bd9b8a1-bf1b-4999-8bb2-11839ed5cc06\",\"email\":\"email 590\",\"phones\":[{\"number\":\"98-63-12\"},{\"number\":\"49-36-95\",\"type\":\"HOME\"},{\"number\":\"24-81-62\",\"type\":\"WORK\"}],\"lastUpdated\":\"2021-05-29T17:23:11.963003464Z\"},{\"name\":\"name 666\",\"id\":\"629fad5c-ce7b-4265-9dcc-be99aac9bf63\",\"email\":\"email 545\",\"phones\":[{\"number\":\"50-92-79\"},{\"number\":\"18-63-76\",\"type\":\"HOME\"},{\"number\":\"31-33-11\",\"type\":\"WORK\"}],\"lastUpdated\":\"2021-05-29T17:23:11.963026415Z\"}]}"
```

## Conclusão

Após os testes, é fácil concluir que o uso do Protocol Buffer no formato binário é melhor nos 3 quesitos em relação ao JSON: faz mais operações por segundo na serialização (~ +3%) e deserialização (~ +400%), a API suporta mais requests por segundo no `POST` (~ +9%) e `GET` (~ +3.5%) e o tamanho do dado serializado é menor (~ -55%). Por outro lado, o Protocol Buffer como JSON performou menos que o JSON, não sendo aconselhado o uso. A desvantagem é que como é um formato binário, o dado salvo não é legível. Mas entendo que é um desvantagem pequena, já que será o software que irá manipular o dado e não um humano.

É impressionante a diferença de tamanho do dado serializado (-55%). Pensando em aplicações grandes, que trafegam um grande volume de dados via rede e armazena esses dados em caches e banco de dados, é fácil perceber a grande vantagem que o uso do Protocol Buffer trás: dados serão trafegados mais rapidamente, usará menos banda de rede e usará menos espaço para armazenamento, que no final significará economia de dinheiro.

Além disso, com as ferramentas de geração de código em várias linguagens a partir do `schema` definido, a integração de clients se torna mais simples, apesar de haver preocupações em relação à evolução do `schema`. Outra ferramenta que é interessantre nesse ponto é o [gRPC](https://grpc.io/), mas isso fica pra outro post. :)

## Referências
- https://developers.google.com/protocol-buffers
- https://developers.google.com/protocol-buffers/docs/reference/overview
- https://github.com/michelaquino/protobuffer-json-comparison
- [1] [Kleppmann, Martin. Designing Data-Intensive Applications. O'Reilly Media](https://www.amazon.com.br/Designing-Data-Intensive-Applications-Reliable-Maintainable-ebook/dp/B06XPJML5D)