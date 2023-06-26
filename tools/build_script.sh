#!/bin/bash -x
if [ "$1" = "" ] 
then 
    echo 1st param - compiler name, like 'gcc' / 'icx' / 'icc' / 'gcc-11' / 'clang-14'
    exit
fi

if [ "$2" = "" ]
then 
    printf "2nd param - experiment name, like:\n
    'default' / 'O3_flto' / 'O3_flto_deps' /\n
    'O3' / 'O3_deps' / 'O2_flto' / 'O2_flto_deps' /\n
    'O2' / 'O2_deps' / 'default_native' / 'O3_native' /\n
    'O2_flto_native' / 'O3_flto_native' / 'default_native_deps' / 'O3_native_deps' /\n
    'O2_flto_native_deps' / 'O3_flto_native_deps' / 'default_icelake' / 'O3_flto_debug' /\n
    'fno_plt' / 'fno_sem' / 'fno_plt_fno_sem'  "
    exit
fi

if [ "$3" = "" ]
then 
    echo 3rd param - host type, like 'AWS' / 'BM'
    exit
fi

if [ "$4" = "" ]
then
    echo 4th param - commit in format '1f76bb1'
    exit
fi


export COMP=$1
export OPTION=$2
export HOST_TYPE=$3
export COMMIT=$4
export EXP_BUILD="$COMP"_"$OPTION"_"$COMMIT"

# ----------- COMPILER SECTION ----------- #
YCC=$COMP
if [ "$COMP" = "gcc" ]; then
    YCXX=g++
fi
if [ "$COMP" = "icx" ]; then
    YCXX=icpx
fi
if [ "$COMP" = "icc" ]; then
    YCXX=icpc
fi
if [ "$COMP" = "gcc-11" ]; then
    YCXX=g++-11
fi
if [ "$COMP" = "clang-14" ]; then
    YCXX=clang++-14
fi

# ----------- OPTION SECTION ----------- #
## ---- O3 ---- ## 

if [ "$OPTION" = "O3" ]; then
    OPT=REDIS_CFLAGS='-O3'
    LDOPT=REDIS_LDFLAGS='-O3'
fi
if [ "$OPTION" = "O3_deps" ]; then
    OPT=CFLAGS='-O3'
    LDOPT=LDFLAGS='-O3'
fi
if [ "$OPTION" = "O3_flto" ]; then
    OPT=REDIS_CFLAGS='-O3 -flto'
    LDOPT=REDIS_LDFLAGS='-O3 -flto'
    if [ "$COMP" = "icc" ]; then
        OPT=REDIS_CFLAGS='-O3 -ipo'
        LDOPT=REDIS_LDFLAGS='-O3 -ipo'
    fi
fi
if [ "$OPTION" = "O3_flto_deps" ]; then
    OPT=CFLAGS='-O3 -flto'
    LDOPT=LDFLAGS='-O3 -flto'
    if [ "$COMP" = "icc" ]; then
        OPT=CFLAGS='-O3 -ipo'
        LDOPT=LDFLAGS='-O3 -ipo'
    fi
fi

if [ "$OPTION" = "O3_flto_opt" ]; then
    LDOPT=REDIS_LDFLAGS='-O3 -flto'
    OPT=OPTIMIZATION='-O3 -flto'
    if [ "$COMP" = "icc" ]; then
        OPT=OPTIMIZATION='-O3 -ipo'
        LDOPT=REDIS_LDFLAGS='-O3 -ipo'
    fi
fi

if [ "$OPTION" = "O3_flto_debug" ]; then
    LDOPT=REDIS_LDFLAGS='-O3 -flto -g'
    OPT=OPTIMIZATION='-O3 -flto -g'
    if [ "$COMP" = "icc" ]; then
        OPT=OPTIMIZATION='-O3 -ipo -g'
        LDOPT=REDIS_LDFLAGS='-O3 -ipo -g'
    fi
fi



## ---- O2 ---- ## 

if [ "$OPTION" = "O2" ]; then
    OPT=REDIS_CFLAGS='-O2'
    LDOPT=REDIS_LDFLAGS='-O2'
fi
if [ "$OPTION" = "O2_deps" ]; then
    OPT=CFLAGS='-O2'
    LDOPT=LDFLAGS='-O2'
fi
if [ "$OPTION" = "O2_flto" ]; then
    OPT=REDIS_CFLAGS='-O2 -flto'
    LDOPT=REDIS_LDFLAGS='-O2 -flto'
    if [ "$COMP" = "icc" ]; then
        OPT=REDIS_CFLAGS='-O2 -ipo'
        LDOPT=REDIS_LDFLAGS='-O2 -ipo'
    fi
fi
if [ "$OPTION" = "O2_flto_deps" ]; then
    OPT=CFLAGS='-O2 -flto'
    LDOPT=LDFLAGS='-O2 -flto'
    if [ "$COMP" = "icc" ]; then
        OPT=CFLAGS='-O2 -ipo'
        LDOPT=LDFLAGS='-O2 -ipo'
    fi
fi

## ---- native ---- ## 
if [ "$OPTION" = "default_native" ]; then
    OPT=REDIS_CFLAGS='-march=native'
    LDOPT=REDIS_LDFLAGS='-march=native'
fi

if [ "$OPTION" = "default_icelake" ]; then # for icc specific
    OPT=REDIS_CFLAGS='-march=icelake'
    LDOPT=REDIS_LDFLAGS='-march=icelake'
fi


if [ "$OPTION" = "O3_native" ]; then
    OPT=REDIS_CFLAGS='-O3 -march=native'
    LDOPT=REDIS_LDFLAGS='-O3 -march=native'
fi

if [ "$OPTION" = "default_native_deps" ]; then
    OPT=CFLAGS='-march=native'
    LDOPT=LDFLAGS='-march=native'
fi

if [ "$OPTION" = "O3_native_deps" ]; then
    OPT=CFLAGS='-O3 -march=native'
    LDOPT=LDFLAGS='-O3 -march=native'
fi

if [ "$OPTION" = "O2_flto_native" ]; then
    OPT=REDIS_CFLAGS='-O2 -flto -march=native'
    LDOPT=REDIS_LDFLAGS='-O2 -flto -march=native'
    if [ "$COMP" = "icc" ]; then
        OPT=REDIS_CFLAGS='-O2 -ipo -march=native'
        LDOPT=REDIS_LDFLAGS='-O2 -ipo -march=native'
    fi
fi
if [ "$OPTION" = "O2_flto_native_deps" ]; then
    OPT=CFLAGS='-O2 -flto -march=native'
    LDOPT=LDFLAGS='-O2 -flto -march=native'
    if [ "$COMP" = "icc" ]; then
        OPT=CFLAGS='-O2 -ipo -march=native'
        LDOPT=LDFLAGS='-O2 -ipo -march=native'
    fi
fi


if [ "$OPTION" = "O3_flto_native" ]; then
    OPT=REDIS_CFLAGS='-O3 -flto -march=native'
    LDOPT=REDIS_LDFLAGS='-O3 -flto -march=native'
    if [ "$COMP" = "icc" ]; then
        OPT=REDIS_CFLAGS='-O3 -ipo -march=native'
        LDOPT=REDIS_LDFLAGS='-O3 -ipo -march=native'
    fi
fi
if [ "$OPTION" = "O3_flto_native_deps" ]; then
    OPT=CFLAGS='-O3 -flto -march=native'
    LDOPT=LDFLAGS='-O3 -flto -march=native'
    if [ "$COMP" = "icc" ]; then
        OPT=CFLAGS='-O3 -ipo -march=native'
        LDOPT=LDFLAGS='-O3 -ipo -march=native'
    fi
fi

if [ "$OPTION" = "O3_flto_native_debug" ]; then
    OPT=REDIS_CFLAGS='-O3 -flto -march=native -g'
    LDOPT=REDIS_LDFLAGS='-O3 -flto -march=native -g'
    if [ "$COMP" = "icc" ]; then
        OPT=REDIS_CFLAGS='-O3 -ipo -march=native -g'
        LDOPT=REDIS_LDFLAGS='-O3 -ipo -march=native -g'
    fi
fi

if [ "$OPTION" = "fno_plt" ]; then
    REDIS_CFLAGS='-fno-plt'
    REDIS_LDFLAGS='-fno-plt'
    export_only=true
    # REDIS_CFLAGS="-fno-plt" REDIS_LDFLAGS="-fno-plt" make  VERBOSE=1 V=1
fi

if [ "$OPTION" = "fno_sem" ]; then
    REDIS_CFLAGS='-fno-semantic-interposition'
    REDIS_LDFLAGS='-fno-semantic-interposition'
    export_only=true
    # REDIS_CFLAGS="-fno-semantic-interposition" REDIS_LDFLAGS="-fno-semantic-interposition" make  VERBOSE=1 V=1
fi

if [ "$OPTION" = "fno_plt_fno_sem" ]; then
    REDIS_CFLAGS='-fno-plt -fno-semantic-interposition'
    REDIS_LDFLAGS='-fno-plt -fno-semantic-interposition'
    export_only=true
    # REDIS_CFLAGS="-fno-plt -fno-semantic-interposition" REDIS_LDFLAGS="-fno-plt -fno-semantic-interposition" make  VERBOSE=1 V=1
fi


# ----------- HOST TYPE SECTION ----------- #

if [ "$HOST_TYPE" = "AWS" ]
then
    git clone https://github.com/redis/redis.git 'redis_'$EXP_BUILD
fi

if [ "$HOST_TYPE" = "BM" ]
then
    tar -xvf redis.tar.gz
    mv redis_archive redis_$EXP_BUILD
fi
cd redis_$EXP_BUILD && git checkout $COMMIT


# ----------- BUILD SECTION ----------- #
if [ "$OPTION" = "default" ]
then
    CC=$YCC CXX=$YCXX make V=1 |& tee build_$EXP_BUILD.log
else
    if [ "$export_only" = true ]
    then
        REDIS_CFLAGS=$REDIS_CFLAGS REDIS_LDFLAGS=$REDIS_LDFLAGS CC=$YCC CXX=$YCXX make V=1 |& tee build_$EXP_BUILD.log
    else
        CC=$YCC CXX=$YCXX make "$OPT" "$LDOPT" V=1 |& tee build_$EXP_BUILD.log
    fi
fi
 

# run server
# mkdir server_logs
# ./src/redis-server --port 6379 --dir server_logs --logfile server_$EXP_BUILD.log --save ""

mkdir ../r_servers
cp ./src/redis-server ../r_servers/redis-server_$EXP_BUILD
