mkdir bin

clang -g -O2 -std=c11 -Wall -framework ApplicationServices enable_grayscale.c -o bin/enable_grayscale

clang -g -O2 -std=c11 -Wall -framework ApplicationServices disable_grayscale.c -o bin/disable_grayscale
