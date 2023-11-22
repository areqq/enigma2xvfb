# enigma2xvfb

Enigma2 python3 in docker

```
docker -l debug  build  . --tag enigmapc
```

```
docker run --rm -p 5900:5900  --name enigma2_box enigmapc  x11vnc -forever  -passwd q
```

```
docker exec -it enigma2_box bash
```
