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
    print('Cython import ignored')
else:
    try:
        from Cython.Distutils import build_ext
        have_cython = True
        cmdclass['build_ext'] = build_ext
    except ImportError:
        print('**** Cython is required to compile audiostream ****')
        raise

# configure the env
use_sdl2 = environ.get('USE_SDL2')
if use_sdl2:
    include_dirs = []
    sdl_include_dir = environ.get('SDL2_INCLUDE_DIR')
    if sdl_include_dir:
        include_dirs.extend(sdl_include_dir.split(':'))
    include_dirs.append('/usr/include/SDL2')
    libraries = ['SDL2', 'SDL2_mixer']
else:
    libraries = ['SDL', 'SDL_mixer']
    include_dirs = ['/usr/include/SDL']
library_dirs = []
extra_objects = []
extra_compile_args =['-ggdb', '-O2']
extra_link_args = []
extensions = []

if not have_cython:
    libraries = ['SDL2', 'SDL2_mixer'] if use_sdl2 else ['sdl', 'sdl_mixer']
else:
    include_dirs.append('.')
    include_dirs.append('/usr/include/SDL')

# generate an Extension object from its dotted name
def makeExtension(extName, files=None):
    extPath = extName.replace('.', os.path.sep) + (
            '.c' if not have_cython else '.pyx')
    if files is None:
        files = []
    return Extension(
        extName,
        [extPath] + files,
        include_dirs=include_dirs,
        library_dirs=library_dirs,
        libraries=libraries,
        extra_objects=extra_objects,
        extra_compile_args=extra_compile_args,
        extra_link_args=extra_link_args
        )

if platform == 'android':
    extensions.append(makeExtension('audiostream.platform.plat_android'))

elif platform == 'ios':
    include_dirs = [
            join(kivy_ios_root, 'build', 'include'),
            join(kivy_ios_root, 'build', 'include', 'SDL')]
    extra_link_args = [
        '-L', join(kivy_ios_root, 'build', 'lib'),
        '-undefined', 'dynamic_lookup']
    extensions.append(makeExtension('audiostream.platform.plat_ios',
        [join('audiostream', 'platform', 'ios_ext.m')]))

elif platform == "darwin":
    include_dirs.append('/usr/local/include/SDL')
    extensions.append(makeExtension('audiostream.platform.plat_mac',
        [join('audiostream', 'platform', 'mac_ext.m')]))

config_pxi = join(dirname(__file__), 'audiostream', 'config.pxi')
with open(config_pxi, 'w') as fd:
    fd.write('DEF PLATFORM = "{}"'.format(platform))


# indicate which extensions we want to compile
extensions += [makeExtension(x) for x in (
    'audiostream.sources.thread',
    'audiostream.sources.wave',
    'audiostream.sources.puredata',
    'audiostream.core')]

setup(
    name='audiostream',
    version='0.2',
    author='Mathieu Virbel, Dustin Lacewell',
    author_email='mat@kivy.org',
    packages=['audiostream', 'audiostream.sources', 'audiostream.platform'],
    url='http://txzone.net/',
    license='LGPL',
    description='An audio library designed to let the user stream to speakers',
    ext_modules=extensions,
    cmdclass=cmdclass,
)
