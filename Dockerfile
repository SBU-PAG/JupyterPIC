#FROM debian:10

#RUN deb http://archive.debian.org/debian-archive/ oldstable main contrib non-free && \
#    deb-src http://archive.debian.org/debian-archive/ oldstable main contrib non-free

# Update the underlying Linux distubtion inside the container
#RUN apt-get update -y && \
#    apt-get install gcc-4.8

#RUN wget https://ftp.gnu.org/gnu/gcc/gcc-6.3.0/gcc-6.3.0.tar.bz2 && \
#    tar jxvf gcc-6.3.0.tar.bz2 && \
#    cd gcc-6.3.0 && \
#    ./contrib/download_prerequisites
#RUN cd ~ && \
#    mkdir gcc-build && cd gcc-build && \
#    ../gcc-6.3.0/configure -v --prefix=$HOME/gcc-6.3.0 && \
#    make && \
#    make install

# Get GCC
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
    gfortran \
    gcc \
    g++ \
    && apt-get install -y wget \
    && apt-get clean  
   
RUN apt-get install -y python3  
RUN apt-get install -y python-is-python3 
RUN apt-get update && apt-get install -y \ 
    python3-jupyter-core \
    jupyter-notebook  

RUN apt-get install -y pip
RUN apt-get install -y ssh



# Make the final directories where all our compiled libraries will reside
RUN mkdir /osiris_libs
RUN mkdir /osiris_libs/hdf5
RUN mkdir /osiris_libs/mpi
RUN mkdir /osiris_libs/fftw

#
# Configure + Build FFTW
#
# Note: We build FFTW twice. The first build is for Double precision floating point.
#                            The second build is for Single precision floating point.
#
RUN apt-get update && apt-get install make
WORKDIR /root
RUN wget  http://www.fftw.org/pub/fftw/fftw-3.3.9.tar.gz
RUN tar xzvf fftw-3.3.9.tar.gz
WORKDIR /root/fftw-3.3.9
RUN ./configure --prefix=/osiris_libs/fftw && make && make install
# RUN make clean
# RUN ./configure MAKE=gmake --enable-float --prefix=/osiris_libs/fftw && make && make install
# RUN /bin/bash -c "./configure --prefix=/osiris_libs/fftw && make && make install"
#
# Configure + Build OpenMPI
#
WORKDIR /root
RUN wget https://www.open-mpi.org/software/ompi/v4.1/downloads/openmpi-4.1.5.tar.gz
RUN tar xvzf openmpi-4.1.5.tar.gz
WORKDIR /root/openmpi-4.1.5
RUN ./configure --enable-mpi-fortran=all --prefix=/osiris_libs/mpi
RUN make
RUN make install
RUN ldconfig

#
# Setup path for MPI
#   (needed so that we can use 'mpicc', 'mpif90' so that HDF5 can be compiled with MPI support)
#
ENV H5_ROOT=/osiris_libs/hdf5
ENV OPENMPI_ROOT=/osiris_libs/mpi
ENV PATH="/osiris_libs/mpi/bin:${PATH}"

#
# Configure + Build HDF5 (with MPI support)
#
WORKDIR /root
RUN wget https://support.hdfgroup.org/ftp/HDF5/current/src/hdf5-1.10.5.tar
RUN tar xvf hdf5-1.10.5.tar
WORKDIR /root/hdf5-1.10.5
RUN ./configure --enable-fortran --enable-parallel --enable-shared --prefix=/osiris_libs/hdf5 CC=mpicc FC=mpif90 F90=mpif90
RUN make
RUN make install

#
# Final setup and cleanup
#
WORKDIR /root
RUN ln -s /usr/local/bin/gcc /usr/local/bin/gcc-4.8
ENV LD_LIBRARY_PATH=/osiris_libs/hdf5/lib
run chmod -R 757 /osiris_libs
ENV PATH="/osiris_libs/mpi/bin:${PATH}"
ENV TERM=xterm-256color

# Remove build files.. when the image is built with the --squash option,
#  removing these files can reduce the image size by 40 percent.
RUN rm -rf hdf5* && rm -rf openmpi* && rm -rf fftw*

USER root

# This is to solve an issue with permissions when running under Windows
#RUN conda install -c anaconda jupyter_client=5.3.1

#
# OSIRIS
#

RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
    gfortran \
    openmpi-bin \
    openmpi-common \
    openmpi-doc \
    gcc \
    openssh-client \
    libopenmpi-dev \
    libhdf5-openmpi-dev \
    && rm -rf /var/lib/apt/lists/*
# RUN apt-get install -y python
# RUN apt-get install -y python-is-python3

# ************************************************************************
# ************************************************************************
# Install json-Fortran for QuickPIC
# RUN pip install FoBiS.py
# RUN conda install --channel conda-forge json-fortran
# ************************************************************************
# ************************************************************************

# *************************************************************************
# Configure + Build HDF5 (with MPI support)
#
# WORKDIR /root
# RUN wget https://support.hdfgroup.org/ftp/HDF5/current/src/hdf5-1.10.5.tar
# RUN tar xvf hdf5-1.10.5.tar
# WORKDIR /root/hdf5-1.10.5
# RUN ./configure --enable-fortran --enable-parallel --enable-shared --prefix=/osiris_libs/hdf5 CC=mpicc FC=mpif90 F90=mpif90
# RUN make
# RUN make install
# **************************************************************************


# ENV H5_ROOT /usr/lib/x86_64-linux-gnu/hdf5/openmpi/lib
ENV H5_ROOT="/usr/lib/aarch64-linux-gnu/hdf5/openmpi/"
ENV OMPI_MCA_btl_vader_single_copy_mechanism=none

RUN mkdir /usr/local/osiris
RUN mkdir /usr/local/beps
RUN mkdir /usr/local/quickpic
RUN mkdir /usr/local/oshun
ENV PATH=$PATH:/usr/local/osiris:/usr/local/beps:/usr/local/quickpic:/usr/local/oshun
ENV PYTHONPATH=/usr/local/osiris:/usr/local/quickpic:/usr/local/oshun
COPY bin/osiris-1D.e /usr/local/osiris/osiris-1D.e
COPY bin/osiris-2D.e /usr/local/osiris/osiris-2D.e
COPY bin/upic-es.out /usr/local/beps/upic-es.out
COPY bin/qpic.e /usr/local/quickpic/qpic.e
COPY bin/oshun.e /usr/local/oshun/oshun.e
COPY analysis/osiris.py /usr/local/osiris/osiris.py
COPY analysis/combine_h5_util_1d.py /usr/local/osiris/combine_h5_util_1d.py
COPY analysis/combine_h5_util_2d.py /usr/local/osiris/combine_h5_util_2d.py
COPY analysis/combine_h5_util_2d_true.py /usr/local/osiris/combine_h5_util_2d_true.py
COPY analysis/combine_h5_util_3d.py /usr/local/osiris/combine_h5_util_3d.py
COPY analysis/analysis.py /usr/local/osiris/analysis.py
COPY analysis/h5_utilities.py /usr/local/osiris/h5_utilities.py
COPY analysis/str2keywords.py /usr/local/osiris/str2keywords.py
COPY analysis/quickpic.py /usr/local/quickpic/quickpic.py
COPY analysis/oshunroutines.py /usr/local/oshun/oshunroutines.py
COPY analysis/heatflowroutines.py /usr/local/oshun/heatflowroutines.py
COPY analysis/osh5def.py /usr/local/oshun/osh5def.py
COPY analysis/osh5gui.py /usr/local/oshun/osh5gui.py
COPY analysis/osh5io.py /usr/local/oshun/osh5io.py
COPY analysis/osh5io_dummy.py /usr/local/oshun/osh5io_dummy.py
COPY analysis/osh5utils.py /usr/local/oshun/osh5utils.py
COPY analysis/osh5vis.py /usr/local/oshun/osh5vis.py
COPY analysis/osh5visipy.py /usr/local/oshun/osh5visipy.py
RUN chmod -R 711 /usr/local/osiris/osiris-1D.e
RUN chmod -R 711 /usr/local/osiris/osiris-2D.e
RUN chmod -R 711 /usr/local/beps/upic-es.out
RUN chmod -R 711 /usr/local/quickpic/qpic.e
RUN chmod -R 711 /usr/local/oshun/oshun.e

WORKDIR work
COPY notebooks notebooks
RUN chmod 777 notebooks
WORKDIR notebooks
RUN chmod 777 electron-plasma-wave-dispersion
RUN chmod 777 faraday-rotation
RUN chmod 777 light-wave-dispersion
RUN chmod 777 light-wave-vacuum-into-plasma
RUN chmod 777 r-and-l-mode-dispersion
RUN chmod 777 two-stream
RUN chmod 777 velocities
RUN chmod 777 x-and-o-mode-dispersion
RUN chmod 777 x-mode-propagation

WORKDIR ..
COPY dev dev
RUN chmod 777 dev
WORKDIR dev
RUN chmod 777 Forslund-Kindel-Lindman-1975
RUN chmod 777 Landau-Damping
RUN chmod 777 Tajima-Dawson-1979
RUN chmod 777 buneman
RUN chmod 777 driven_waves
RUN chmod 777 heatflow_oshun
RUN chmod 777 iaw-fluid-theory
RUN chmod 777 interactive-theory
RUN chmod 777 quickpic_pwfa
RUN chmod 777 weibel
RUN chmod 777 RPA
RUN chmod 777 SBS
RUN chmod 777 TPD
RUN chmod 777 forslund-SRS
RUN chmod 777 grid-instability
RUN chmod 777 single-particle
RUN chmod 777 Leap-Frog

WORKDIR ..
COPY notebooks-260 notebooks-260
RUN chmod 777 notebooks-260
WORKDIR notebooks-260
RUN chmod 777 LWFA-Workbook-1-Tajima-Dawson
RUN chmod 777 Single-Particle-Workbook
RUN chmod 777 PWFA

WORKDIR ..
# COPY NERS-574 NERS-574
# RUN chmod 777 NERS-574
# WORKDIR NERS-574
# RUN chmod 777 faraday-rotation
# RUN chmod 777 light-wave-dispersion
# RUN chmod 777 light-wave-vacuum-into-plasma
# RUN chmod 777 r-and-l-mode-dispersion
# RUN chmod 777 velocities
# RUN chmod 777 x-and-o-mode-dispersion
# RUN chmod 777 x-mode-propagation
# RUN chmod 777 LWFA-Workbook-1-Tajima-Dawson
# RUN chmod 777 LWFA-Basic-Notebook


USER $NB_USER 
WORKDIR ..

RUN pip install h5py
RUN pip install matplotlib
RUN pip install numpy
RUN pip install scipy
RUN pip install ipywidgets
# 
# RUN pip install nbgitpuller==1.2.1 jupyter-resource-usage "matplotlib<3.9.0"
# RUN pip install nbgitpuller==1.2.1 jupyter-resource-usage matplotlib==3.2.0
#
CMD ["jupyter", "notebook", "--notebook-dir=\"/home/jovyan\"", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
