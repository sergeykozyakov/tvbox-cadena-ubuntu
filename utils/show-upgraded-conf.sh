#!/bin/bash

sudo find /etc -type f \( -name "*.dpkg-dist" -o -name "*.dpkg-old" -o -name "*.dpkg-new" \)
