A CSV format library for Haxe
=============================

Essentially a cross-platform streaming reader with support for UTF-8 and
variable control strings (end of line sequence, separator and escape
characters).

The writer has yet to be implemented.

[![Build Status](https://travis-ci.org/jonasmalacofilho/csv-rdp.svg?branch=master)](https://travis-ci.org/jonasmalacofilho/csv-rdp)


Usage
-----

Strings:

```haxe
import format.csv.*;
[...]

var csv:String;  // some data in CSV

trace(Reader.read(csv));       // native strings, default control strings ,"\n
trace(Utf8Reader.read(csv));   // ensure proper Utf8 handling (not always necessary)
trace(Reader.read(csv, "|"));  // use | for separator
```

Streams (`haxe.io.Input`):

```haxe
import format.csv.*;
[...]

var input:haxe.io.Input;    // CSV data in a File, Socket or other Input subclass

// create a reader
var reader = new Reader(",", "\"", "\n");

// reset the reader with the stream
reader.reset(null, input);  // a string or a combination of both string and input can also be used
                            // to reset; the reader will always try to start with the string and
                            // then pass to the stream

// use the iterable interface
for (record in reader)
    trace(record);  // do some work, without first having to read the entire stream
// or read everything
trace(reader.readAll());
```


Implementation
--------------

The reader uses a recursive descent parser.  Although it's arguably more
verbose than other implementations, specially those without simultaneous
support for streams (`haxe.io.Input`) and UTF-8, the code should be quite easy
to read, debug or change.

Almost everything needed for UTF-8 support comes from `haxe.Utf8`, except for a
reimplementation of the validation function for bytes.  This is needed for all
targets with pre-defined string encoding; on them, creating a string from
invalid or incomplete bytes will result in a error, either immediately or when
they're first used.

