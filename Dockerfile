FROM debian:stretch

ENV S3FS_VERSION=1.86 S3FS_SHA1=b780ae7841eeac476028327f5f09a5a726a3d88a

COPY ./build-s3fs.sh /build-s3fs.sh
COPY ./flexvolume.sh /flexvolume.sh
COPY ./s3flex /s3flex
COPY ./entrypoint.sh /entrypoint.sh

RUN /build-s3fs.sh

CMD /bin/sh /entrypoint.sh