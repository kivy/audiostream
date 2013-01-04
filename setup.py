import sys
import os
from os.path import join, dirname
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
cmdclass = {}
if platform in ('android', 'ios'):
    print 'Cython import ignored'
else:
    try:
        from Cython.Distutils import build_ext
        have_cython = True
        cmdclass['build_ext'] = build_ext
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

# indicate which extensions we want to compile
extensions = [
    'audiostream.sources.thread',
    'audiostream.sources.wave',
    'audiostream.sources.puredata',
    'audiostream.core']

if platform == 'android':
    extensions.append('audiostream.platform.plat_android')

config_pxi = join(dirname(__file__), 'audiostream', 'config.pxi')
with open(config_pxi, 'w') as fd:
    fd.write('DEF PLATFORM = "{}"'.format(platform))

setup(
    name='audiostream',
    version='1.0',
    author='Mathieu Virbel, Dustin Lacewell',
    author_email='mat@kivy.org',
    packages=['audiostream', 'audiostream.sources', 'audiostream.platform'],
    url='http://txzone.net/',
    license='LGPL',
    description='An audio library designed to let the user stream to speakers',
    ext_modules=[makeExtension(x) for x in extensions],
    cmdclass=cmdclass,
)
