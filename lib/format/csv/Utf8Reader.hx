package format.csv;

import format.csv.Data;
import haxe.Utf8;
import haxe.io.*;

class Utf8Reader extends Reader {
    override function substring(str, pos, ?length:Null<Int>)
    {
        if (length == null)
            length = Utf8.length(str);
        return Utf8.sub(str, pos, length);
    }

    override function stringLength(str)
    {
        return Utf8.length(str);
    }

    function validUtf8(bytes, pos, len)
    {
        // adapted from neko/libs/std/utf8.c@utf8_validate
        while (pos < len) {
            var e = pos;
            var c = bytes.get(pos++);
            if (c < 0x7f) {
                // ok
            } else if (c < 0xc0) {
                return e;
            } else if (c < 0xe0) {
                if (pos >= len || bytes.get(pos++) & 0x80 != 0x80)
                    return e;
            } else if (c < 0xf0) {
                if (pos >= len || bytes.get(pos++) & 0x80 != 0x80)
                    return e;
                if (pos >= len || bytes.get(pos++) & 0x80 != 0x80)
                    return e;
            } else {
                if (pos >= len || bytes.get(pos++) & 0x80 != 0x80)
                    return e;
                if (pos >= len || bytes.get(pos++) & 0x80 != 0x80)
                    return e;
                if (pos >= len || bytes.get(pos++) & 0x80!= 0x80)
                    return e;
            }
        }
        return -1;
    }

    override function fetchBytes(n)
    {
        if (inp == null)
            return null;

        try {
            var bytes = Bytes.alloc(n + 3);
            var got = inp.readBytes(bytes, 0, n);

            var e = validUtf8(bytes, 0, got);
            for (i in 0...3) {
                if (e == -1)  // ok
                    break;
                got += inp.readBytes(bytes, got, 1);
                e = validUtf8(bytes, e, got);
            }

#if (haxe_ver >= 3.13)
            if (e != -1)
                throw 'Invalid Utf8 stream: [...]${bytes.getString(e, got - 3)}';
            return bytes.getString(0, got);
#else
            if (e != -1)
                throw 'Invalid Utf8 stream: [...]${bytes.readString(e, got - 3)}';
            return bytes.readString(0, got);
#end
        } catch (e:Eof) {
            return null;
        }
    }

    /*
       Create a new Reader.

       Creates a UTF-8 specific Csv reader.

       Optional parameters:

        - `separator`: 1-char separator string (default: ASCII comma)
        - `escape`: 1-char escape string (default: ASCII double quote)
        - `endOfLine`: allowed end-of-line sequences (default: either CRLF or LF)
    */
    public function new(?separator, ?escape, ?endOfLine:Array<String>)
    {
        super(separator, escape, endOfLine);
    }

    /*
       Read and return an array with all records in `text`.

       Tip: use this to statically extend Input
    */
    public static function readCsv(stream:Input, ?separator, ?escape, ?endOfLine:Array<String>):Utf8Reader
    {
        var p = new Utf8Reader(separator, escape, endOfLine);
        p.inp = stream;
        return p;
    }

    /*
       Read and return an array with all records in `text`.

       Tip: use this to statically extend String
    */
    public static function parseCsv(text:String, ?separator, ?escape, ?endOfLine:Array<String>):Array<Record>
    {
        var p = new Utf8Reader(separator, escape, endOfLine);
        p.buffer = text;
        return p.readAll();
    }

    /*
       Read and return an array with all records in `text`.

       Deprecated: use `parseCsv(text, ...)` instead.
    */
    @:deprecated("read(text, ...) has been deprecated; use parseCsv(text, ...) instead")
    public static inline function read(text:String, ?separator, ?escape, ?endOfLine:Array<String>):Array<Record>
    {
        return parseCsv(text, separator, escape, endOfLine);
    }
}

