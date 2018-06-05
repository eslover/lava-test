#!/bin/bash

WD=/opt/viv_samples/vdk

cd $WD

glmark2-es2-wayland --run-forever > /dev/null 2>&1 &
weston-simple-egl > /dev/null 2>&1 &
./tutorial3_es20 > /dev/null 2>&1 &

