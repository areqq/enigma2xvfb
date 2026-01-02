FROM ubuntu:24.04

# build requirements
RUN apt-get update && apt-get install -y \
  git build-essential autoconf autotools-dev libtool libtool-bin checkinstall unzip \
  cmake ninja-build pkg-config libarchive-dev libsolv-dev zstd libcurl4-openssl-dev libssl-dev libgpgme-dev libgpg-error-dev \
  swig python3-dev python3-pip python3-twisted python3-netifaces python3-requests python3-full \
  libz-dev libssl-dev libsdl1.2-dev\
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libfreetype6-dev libfribidi-dev libsigc++-3.0-dev \
  libarchive-dev libcurl4-openssl-dev libgpgme11-dev \
  libavahi-client-dev libjpeg-dev libgif-dev libsdl2-dev libxml2-dev curl gettext mm-common wget docbook-xsl mc vim

# xserver, web server
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update & apt-get install -y x11vnc xvfb xdotool tigervnc-standalone-server

WORKDIR /work

ARG OPKG_VER="0.9.0"
RUN curl -L "http://git.yoctoproject.org/cgit/cgit.cgi/opkg/snapshot/opkg-$OPKG_VER.tar.gz" -o opkg.tar.gz
RUN tar -xzf opkg.tar.gz \
 && cd "opkg-$OPKG_VER" \
 && cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr \
 && cmake --build build \
 && cmake --install build

# && ./autogen.sh \
# && ./configure --enable-curl --enable-ssl-curl --enable-gpg \
# && make \
# && make install

RUN git clone https://github.com/mtdcr/libdvbsi
RUN cd libdvbsi \
 && ./autogen.sh \
 && ./configure \
 && make \
 && make install

RUN git clone --depth 10 https://github.com/OpenPLi/tuxtxt.git
RUN cd tuxtxt/libtuxtxt \
 && autoreconf -i \
 && CPP="gcc -E -P" ./configure --with-boxtype=generic --prefix=/usr \
 && make \
 && make install
RUN cd tuxtxt/tuxtxt \
 && autoreconf -i \
 && CPP="gcc -E -P" ./configure --with-boxtype=generic --prefix=/usr \
 && make \
 && make install

#RUN wget https://github.com/libsigcplusplus/libsigcplusplus/releases/download/3.6.0/libsigc%2B%2B-3.6.0.tar.xz
#RUN xz -d libsigc++-3.6.0.tar.xz && tar -xf libsigc++-3.6.0.tar ; cd libsigc++-3.6.0 ;./autogen.sh --prefix=/usr ; ./configure --prefix=/usr ; make ; make install

RUN git clone --depth 10 https://github.com/OpenPLi/enigma2
RUN sed -i 's/-Wextra -Werror//' enigma2/configure.ac

RUN cd enigma2 && autoupdate && autoreconf -v -f -i

RUN cd enigma2 && ./configure \
  --with-libsdl --prefix=/usr --sysconfdir=/etc \
  --enable-dependency-tracking --with-boxtype=nobox \
  PYTHON_CPPFLAGS="-I/usr/include/python3.12"

RUN cd enigma2 && make -j4 && make install

#RUN sed -i 's/.*Network.*//'  /usr/lib/enigma2/python/StartEnigma.py

RUN git clone https://github.com/littlesat/skin-PLiHD && mv skin-PLiHD/usr/share/enigma2/* /usr/share/enigma2/

# disable startup wizards
COPY enigma2-settings /etc/enigma2/settings
RUN rm -fr /usr/lib/enigma2/python/Plugins/SystemPlugins/WirelessLan
RUN /bin/echo -e "architecture=x86_64\ndisplaymodel=pc\ndisplaydistro=q\nimagetype=q\nimageversion=q\noe=q\nkernel=q\ncompiledate='20251231'\nchecksum=821a56640e2ce0e84534c7e227fdd037" > /usr/lib/enigma.info
RUN ldconfig

COPY entrypoint.sh /opt
RUN chmod 755 /opt/entrypoint.sh
ENV DISPLAY=:99
ENV SDL_VIDEO_WINDOW_POS=0,0

EXPOSE 5900 80
ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
