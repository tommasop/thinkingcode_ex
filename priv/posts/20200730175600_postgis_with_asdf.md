{
  "title": "How to install different versions of PostGIS according to ASDF postgres versions",
  "slug": "different-versions-of-postgis-with-asdf-postgres",
  "datetime": "2020-07-30T17:56:00.939105Z"
}
---
How to install different versions of PostGIS according to ASDF postgres versions
---

There is an ongoing discussion on how to better suite the needs of programmers for a
simple to use and not too hardly reproduceable development environment.

Actual viable solutions that can encompass different programming languages are:

1. ASDF
2. Nix
3. Docker

## ASDF

Think an RVM/Rbenv on steroids with a growing number of plugins which now include also postgres.
This is particularly interesting because on linux homebrew does not have the `brew services` command.

## Nix

Functional package manager which is able to ensure full reproduceability of every environment.
This must definitely be the way to go for the future.
The only problem being its implementation has a really steep curve.

## Docker

Still has some problems on OSX. It is definitely useful to start complex enviroments which need to interact
together but it has some drawbacks on the development side.

## My configuration

In the end for my needs the simplest possible configuration which is definitely ASDF.
I have `yadm` configured with a `bootstrap` script which does all the annoying stuff
and use ASDF to install both different version of programming languages and different
versions of postgres.
I also install `homebrew` and have `snap` integrated in my OS (Ubuntu 20.04).
I find that each tool has its own use and its limits. These tools together seem to
be the sweet spot for my developer experience.

## The Problem

For one of my projects I have the need to install PostGIS.
There has been an attempt to have an ASDF plugin for postgis.
It posed some problems wihch have not yet been solved (since 2017) in ASDF.

This mean that are not so felt problems and that people can live with ASDF as is.

So I tried a simpler solution which could work for me.

## PostGIS

The problems with PostGIS are twofold:

1. It needs a huge amount of external libraries to work
2. It must be installed in the same directory as the PostgreSQL version it must be used in

## Solving problem 1

The best tool to solve the need for all libraries (GEOS, GDAL, Proj4 etc.) is
undoubtedly `brew`.

So what I did was:

```
brew install postgis
```

and afterwards uninstall the formulas I didn't need:

```
brew uninstall postgresql postgis
```

## Solving problem 2

Problem 2 can be easily solved with a shell alias + ASDF.

What PostGIS needs is a reachable version of postgres. This can be easily achieved
cding into a folder with an ASDF `.tool-versions` file referencing the target postgresql version.

This will give the shell access to the `pg_config` command which has all the enviroment references
needed for postgres and its extensions.

Then this shell alias is the last piece of the puzzle:

```
# PostGIS install
function getpostigs () {
    wget -q -P tmp/ https://github.com/postgis/postgis/archive/"$@".tar.gz
    tar xvzf tmp/"$@".tar.gz -C tmp/
    cd tmp/postgis-"$@"
    if [[ ! -a ./configure ]]; then
      ./autogen.sh
    fi
    eval ./configure `pg_config --configure`
    make
    make install
    cd ../..
    rm -rf tmp/
}
```

This script can be used like this `getpostgis 2.5.9`.
The most important bit of the script is the line: 

```
eval ./configure `pg_config --configure`
```

this line ensures postgis is configured with a `--prefix` which is the same as the
postgres version used by ASDF in that folder.

I've found that line in the postgresql documentation for `pg_config` id didn't work
with other shell combinations.
