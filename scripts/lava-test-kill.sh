#!/bin/bash

ps -xfg | grep auto_run_base | awk '{print $1} ' | xargs kill
