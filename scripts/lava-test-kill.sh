#!/bin/bash

ps -xfg | grep auto_run_base | awk '{print $1} ' | xargs kill
ps -xfg | grep auto_run_ondemand_base | awk '{print $1} ' | xargs kill
