import os
from os.path import join, realpath
from os import environ
from distutils.core import setup
from distutils.extension import Extension
try:
    from Cython.Distutils import build_ext
    have_cython = True
    cmdclass = { 'build_ext': build_ext }
except ImportError:
    print "*"*20, "NO CYTHON"
    have_cython = False
    cmdclass = {}


libraries = ['SDL', 'SDL_mixer']
library_dirs = []
include_dirs = ['/usr/include/SDL']
extra_objects = []
extra_compile_args =['-ggdb', '-O2']
ext_files = ['audiostream/audiostream.pyx']

if not have_cython:
    ext_files = [x.replace('.pyx', '.c') for x in ext_files]
    libraries = ['sdl', 'sdl_mixer']
else:
    include_dirs.append('.')
    include_dirs.append('/usr/include/SDL')

# scan the 'dvedit' directory for extension files, converting
# them to extension names in dotted notation
def scandir(dir, files=[]):
    for file in os.listdir(dir):
        path = os.path.join(dir, file)
        if os.path.isfile(path) and path.endswith(".pyx"):
            path = path.replace('.pyx', '.c')
            files.append(path.replace(os.path.sep, ".")[:-2])
        elif os.path.isdir(path):
            scandir(path, files)
    return files


# generate an Extension object from its dotted name
def makeExtension(extName):
    extPath = extName.replace(".", os.path.sep)+".c"
    return Extension(
        extName,
        [extPath],
        include_dirs=include_dirs,
        library_dirs=library_dirs,
        libraries=libraries,
        extra_objects=extra_objects,
        extra_compile_args=extra_compile_args,
        )

# get the list of extensions
extNames = scandir("audiostream")

# and build up the set of Extension objects
extensions = [makeExtension(name) for name in extNames]

setup(
    name='audiostream',
    version='1.0',
    author='Mathieu Virbel',
    author_email='mat@kivy.org',
    packages=['audiostream', 'audiostream.sources'],
    url='http://txzone.net/',
    license='LGPL',
    description='An audio library designed to let the user stream to speakers',
    ext_modules=extensions,
    cmdclass=cmdclass,
)
