API
===

Core API
--------

.. py:module:: audiostream

.. py:function:: get_output(rate : int, channels : int, encoding : int) -> `AudioOutput` instance

    Initialize the engine and get an output device. This method can be used
    only once, usually at the start of your application.

    :param rate: Rate of the audio, default to 44100
    :param channels: Number of channels, minimum 1, default to 2
    :param encoding: Encoding of the audio stream, can be 8 or 16, default to 16
    :param buffersize: Size of the output buffer. Tiny buffer will use consume more CPU, but will be more reactive.
    :rtype: :class:`AudioOutput` instance
    :type rate: integer
    :type channels: integer
    :type encoding: integer
    :type buffersize: integer

    Example::

        from audiostream import get_output
        stream = get_output(channels=2, rate=22050, buffersize=1024)

.. py:function:: get_input(callback : callable, source : string, rate : int, channels : int, encoding : int, buffersize : int) -> `AudioInput` instance

    Return an :class:`AudioInput` instance. All the data received from the
    input will be stored in a queue. You need to :meth:`AudioInput.poll` the
    queue regulary in order to trigger the callback.

    Please note that the `callback` will be called in the same thread as the
    one that call :meth:`AudioInput.poll`.

    :param callback: Callback to call when bytes are available on the input, called from the audio thread.
    :param source: Source device to read, default to 'default. Depending of the platform, you might read other input source. Check the :func:`get_input_sources` function.
    :param channels: Number of channels, minimum 1, default to 2
    :param encoding: Encoding of the audio stream, can be 8 or 16, default to 16
    :param buffersize: Size of the input buffer. If <= 0, it will be automatically sized by the system.
    :type callback: callable
    :type source: string
    :type channels: integer
    :type encoding: integer
    :type buffersize: integer
    :rtype: :class:`AudioInput` instance

    Example::

        from audiostream import get_input

        def mic_callback(buf):
            print('got', len(buf))

        # get the default audio input (mic on most cases)
        mic = get_input(callback=mic_callback)
        mic.start()

        while not quit:
            mic.poll()
            # do something here, like sleep(2)

        mic.stop()

    .. note::

        This function currently work only on Android and iOS.

.. py:function:: get_input_sources() -> list of strings

    Return a list of available input sources. This list is platform-dependent.
    You might need some additionnals permissions in order to access to the
    sources.

    * android: 'camcorder', 'default', 'mic', 'voice_call',
      'voice_communication', 'voice_downlink', 'voice_recognition',
      'voice_uplink'
    * ios: 'default'

    .. note::

        This function currently work only on Android and iOS.

.. py:class:: AudioInput(object)

    Abstract class for handling an audio input. Normally, the default audio
    source is the microphone. It will be recorded with a rate of 44100hz, mono,
    with 16bit PCM. Theses defaults are the most used and guaranted to work on
    Android and iOS. Any others combination might fail.

    .. py:method:: start()

        Start the input to gather data from the source

    .. py:method:: stop()

        Stop the input to gather data from the source

    .. py:method:: poll()

        Read the internal queue and dispatch the data through the callback

    .. py:attribute:: callback

        Callback to call when bytes are available on the input, called from the
        audio thread. The callback must have one parameter for receiving the data.

    .. py:attribute:: encoding

        (readonly) Encoding of the audio, can be 8 or 16, default to 16

    .. py:attribute:: source

        (readonly) Source device to read, default to 'default. Depending of the
        platform, you might read other input source. Check the
        :func:`get_input_sources` function.

    .. py:attribute:: channels

        (readonly) Number of channels, minimum 1, default to 2

    .. py:attribute:: buffersize

        (readonly) Size of the input buffer. If <= 0, it will be automatically
        sized by the system.


.. py:class:: AudioOutput(object)

    Abstract class for handling audio output stream, and handle the mixing of
    multiple sample. One sample is an instance of :class:`AudioSample` abstract
    class. You can implement your own sample that generate bytes, and thoses
    bytes will be mixed in the final output stream.

    We also expose multiple `AudioSample` implementation, such as:

    * :class:`audiostream.sources.thread.ThreadSource`: base for implementing a
      generator that run in a thread
    * :class:`audiostream.sources.wave.SineSource`: generate a sine wave
    * :class:`audiostream.sources.puredata.PatchSource`: sample generator that
      use a Puredata patch (require pylibpd)


    .. py:method:: add_sample(sample : AudioSample)

        :param sample: sample to manage in the mixer
        :type sample: :class:`AudioSample`

        Add a sample to manage in the internal mixer. This method is usually
        called in the :meth:`AudioSample.start`

    .. py:method:: remove_sample(sample : AudioSample)

        :param sample: sample managed by the mixer
        :type sample: :class:`AudioSample`

        Remove a sample from the internal mixer. This method is usually called
        in the :meth:`AudioSample.stop`


.. py:class:: AudioSample

    :class:`AudioSample` is a class for generating bytes that will be consumed
    by :class:`AudioOutput'.  The data goes first on a RingBuffer, and the
    buffer is consumed by the speaker, according to the :class:`AudioOutput`
    initialization.

    Example::

        from audiostream import get_output, AudioSample
        stream = get_output(channels=1, buffersize=1024, rate=22050)
        sample = AudioSample()
        stream.add_sample(sample)

        sample.play()
        while True:
            # audio stuff, this is not accurate.
            sample.write("\\x00\\x00\\x00\\x00\\xff\\xff\\xff\\xff")

    If you don't write enough data (underrun), the library will fill with `\\x00`.
    If you write too much (overrun), the write method will block, until the
    data is consumed.

    You should use :class:`audiostream.sources.ThreadSource` instead.


    .. py:method:: write(chunk : bytes)

        :param chunk: Data chunk to write
        :type chunk: bytes

        Write a data chunk into the ring buffer. It will be consumed later by
        the speaker.

    .. py:method:: play()

        Play the sample using the internal ring buffer

    .. py:method:: stop()

        Stop the playback


Sample generators
-----------------

.. py:module:: audiostream.sources.thread

.. py:class:: ThreadSource(AudioSample)

    Sample generator using thread, does nothing by default. It can be used
    to implement your own generator.

    .. py:method:: __init__(stream : AudioOutput)

        :param stream: The :class:`AudioOutput` instance to use
        :type stream: :class:`AudioOutput`

    .. py:method:: get_bytes() -> bytes

        Must return a bytes string with the data to store in the ring buffer.


.. py:module:: audiostream.sources.wave

.. py:class:: SineSource(ThreadSource)

    Sample generator that use the :class:`ThreadSource`, and generate bytes
    from a sin() generator.

    .. py:method:: __init__(stream : AudioOutput, frequency : int)

        :param stream: The :class:`AudioOutput` instance to use
        :param frequency: The sin() frequency, for example: 440.
        :type stream: :class:`AudioOutput`
        :type frequency: integer


.. py:module:: audiostream.sources.puredata

.. py:class:: PatchSource(ThreadSource)

    Load a `PureData <http://puredata.info>` patch, and read the generated
    output.

    .. py:method:: __init__(stream : AudioOutput, patchfile : string)

        :param stream: The :class:`AudioOutput` instance to use
        :param patchfile: The patch filename to load with pylibpd
        :type stream: :class:`AudioOutput`
        :type patchfile: string
