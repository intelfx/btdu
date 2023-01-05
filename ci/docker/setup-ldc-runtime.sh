#!/bin/bash
target_arch=$BTDU_ARCH

cd /tmp

args=(
	env
)

if [[ "$host_arch" != "$target_arch" ]]; then
	args+=(CC="$target_arch"-linux-gnu-gcc)
fi

args+=(
	ldc2-host/bin/ldc-build-runtime
	--dFlags="-mtriple=$target_arch-linux-gnu"
	--dFlags="-flto=full"
	BUILD_SHARED_LIBS=OFF
) ; "${args[@]}"

