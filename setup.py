from os.path import join, realpath
from os import environ
from distutils.core import setup
from distutils.extension import Extension
try:
    from Cython.Distutils import build_ext
    have_cython = True
    cmdclass = { 'build_ext': build_ext }
except ImportError:
    have_cython = False
    cmdclass = {}


libraries = ['SDL', 'SDL_mixer']
library_dirs = []
include_dirs = ['/usr/include/SDL']
extra_objects = []
extra_compile_args =['-ggdb', '-O2']
ext_files = ['audiostream.pyx']

if not have_cython:
    ext_files = [x.replace('.pyx', '.c') for x in ext_files]
    libraries = ['sdl', 'sdl_mixer']
else:
    include_dirs.append('/usr/include/SDL')

ext = Extension(
    'audiostream',
    ext_files,
    include_dirs=include_dirs,
    library_dirs=library_dirs,
    libraries=libraries,
    extra_objects=extra_objects,
    extra_compile_args=extra_compile_args,
)

setup(
    name='audiostream',
    version='1.0',
    author='Mathieu Virbel',
    author_email='mat@kivy.org',
    url='http://txzone.net/',
    license='LGPL',
    description='An audio library designed to let the user streaming to speaker',
    ext_modules=[ext],
    cmdclass=cmdclass,
)
