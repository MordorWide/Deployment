#!/usr/bin/env bash
cd "$(dirname "$0")"
set -e

# Clone the repositories
git clone https://github.com/MordorWide/EANation  mordorwide-eanation
git clone https://github.com/MordorWide/Web       mordorwide-web
git clone https://github.com/MordorWide/Turn      mordorwide-udpturn
git clone https://github.com/MordorWide/StunRelay mordorwide-stunrelay