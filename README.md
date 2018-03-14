# A simple DDS core
This is a simple DDS core, that can be used to generate simple complex sine waves. It has noise shaping features like dithering or taylor series expansion (linear interpolation). It is highly configurable and is intended to be used as a sweep generate as required for FMCW radars.

## Features
- LUT only saves a quater sine waves (optimal for Altera Cycle IV -> 10bit LUT fit in a single block ram)
- Phasedithering
- Linear interpolation between LUT values
- Truncation dithering
- SFDR ~ 80dB

![](https://github.com/spr02/DDS/blob/master/doc/img/20MHZ_example.png)

## Repository overview
This repository contains four folders:
```
	DDS
	|-	doc
	|-	hdl
	|-	matlab
	|-	misc
```

The folder [matlab](matlab) contains the reference model for the DDS core. In the folder [hdl](hdl) all VHDL files can be found, together with a Makefile for ghdl. The folder [misc](misc) contains a README with some useful links. Finally the folder [doc](doc) will contain a documentation soon.

## TODO:
- check automatic verification
