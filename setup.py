import sys
import os
from os.path import join
from os import environ
from distutils.core import setup
from distutils.extension import Extension

# detect Python for android project (http://github.com/kivy/python-for-android)
# or kivy-ios (http://github.com/kivy/kivy-ios)
platform = sys.platform
ndkplatform = environ.get('NDKPLATFORM')
if ndkplatform is not None and environ.get('LIBLINK'):
    platform = 'android'
kivy_ios_root = environ.get('KIVYIOSROOT', None)
if kivy_ios_root is not None:
    platform = 'ios'

# ensure Cython is installed for desktop app
have_cython = False
if platform in ('android', 'ios'):
    print 'Cython import ignored'
else:
    try:
        from Cython.Distutils import build_ext
        have_cython = True
        cmdclass = {'build_ext': build_ext}
    except ImportError:
        print '**** Cython is required to compile audiostream ****'
        raise

# configure the env
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
def scandir(directory, files=[]):
    for fn in os.listdir(directory):
        path = join(directory, fn)
        if os.path.isfile(path) and path.endswith(".pyx"):
            path = path.replace('.pyx', '.c')
            files.append(path.replace(os.path.sep, ".")[:-2])
        elif os.path.isdir(path):
            scandir(path, files)
    return files

# generate an Extension object from its dotted name
def makeExtension(extName):
    extPath = extName.replace('.', os.path.sep) + (
            '.c' if not have_cython else '.pyx')
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
    author='Mathieu Virbel, Dustin Lacewell',
    author_email='mat@kivy.org',
    packages=['audiostream', 'audiostream.sources'],
    url='http://txzone.net/',
    license='LGPL',
    description='An audio library designed to let the user stream to speakers',
    ext_modules=extensions,
    cmdclass=cmdclass,
)
