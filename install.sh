#!/bin/bash

sudo apt update
sudo apt upgrade
sudo apt install ansible cargo -y
sudo cargo install just
sudo apt remove cargo