## usage

```bash
git clone --recursive https://github.com/hugofloresgarcia/peakvibe.git
```

or if you already cloned and forgot to clone the submodules:

```bash
git submodule update --init --recursive
```

## building

```bash
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j install
```

## running

peakvibe is an extension to the REAPER DAW. To run it, follow the instructions above to make and install, then launch reaper: 

(MacOS)
```bash
open /Applications/REAPER.app
```
