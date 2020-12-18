#!/bin/sh

# Start Erlang VM and the tool
erl -sname etracer -pa "ebin/" -run etracer start
