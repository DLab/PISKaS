<!--img src="http://www.pps.jussieu.fr/~jkrivine/homepage/Research_files/droppedImage.jpg" alt="KaSim logo" title="Stochastic Kappa Simulator" align="right" /-->
# PISKaS

PISKaS is a stochastic simulator for rule-based models written in an expanded version of [Kappa-Language](http://dev.executableknowledge.org/), which we call **Spatial Kappa** (see the [wiki](https://github.com/DLab/PISKaS/wiki) of this repository). 
PISKaS is directly based on (and forked from) the repository of the simulation software [KaSim](https://github.com/Kappa-Dev/KaSim) v3.5. The main new features of PISKaS are:

  1. Models must be written in **Spatial Kappa** ([wiki/usage](https://github.com/DLab/PISKaS/wiki#usage)).
  2. Simulations will run using an MPI framework, where every compartment or cell (subcompartments defined with an array notation) use an independent core of the computing architecture.
  3. To run a spatial simulation you need to use the `mpirun` tool of your MPI framework, and give as "number-of-cores" parameter (`-n X`), where `X` is the amount of compartments or cells of your model.
  4. You need to specify the synchronization step for your simulation using the PISKaS argument `-sync-t`. This argument defines the time step to synchronize compartments; a small value gives a slow but accurate simulation and a large value, a fast but unaccurate simulation.

It is recomended to first read the pdf of KaSim reference manual (available [here](https://github.com/Kappa-Dev/KaSim/releases/download/v3.5-190914/KaSim_manual_3_5.pdf)) to learn about stochastic simulation and Kappa-Language.

## Installation

To install you need the ocaml native compiler. To check whether you have it, type 

`ocamlopt.opt -version` 

Ocaml installation tutorial can be found on its [official website](https://ocaml.org/). You will also need the [ocamlMPI library](https://forge.ocamlcore.org/projects/ocamlmpi/) and an MPI framework like [OpenMPI](https://www.open-mpi.org/) for compliation and for running simulations. It is recomended that you install both ocaml and libraries using Opam. To learn about how to do this please visit the [wiki](https://github.com/DLab/PISKaS/wiki) of this repository.

To create PISKaS binaries, simply type 

`make`

This should produce PISKaS binaries. You will need your own plotting program (like gnuplot) to visualize curves.

## Usage

You could run the example file PISKaS/models/predator/predator25.cka. In order to run a simulation of 100 time units, type

`mpirun -n 'num-of-compartments' PISKa -i predator25.cka -t 100 -p 1000 -sync-t 0.5 -o data_file`

This will produce several (one for each compartment) data files of 1000 point (-p option) containing the trajectory that was produced during the simulation with synchronization step of 0.5 time units (ie. 200 synchronizations).

## Help

Type `PISKa --help` for a complete list of options.

