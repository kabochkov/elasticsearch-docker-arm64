# ElasticSearch 6 docker image

# Building the image
```
ES_VERSION=6.8.22
docker build --no-cache --build-arg ES_VERSION=$ES_VERSION -t elasticsearch:arm64-$ES_VERSION --build-arg ARCH=arm64v8 .
```

# Running the image
To run it:

```
docker run -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" -e "xpack.ml.enabled=false" elasticsearch:arm64-$ES_VERSION
```
