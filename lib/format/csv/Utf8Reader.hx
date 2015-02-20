package format.csv;

import format.csv.Data;
import haxe.Utf8;
import haxe.io.*;

class Utf8Reader extends Reader {
    override function substring(str, pos, ?len:Null<Int>)
    {
        if (len == null)
            len = Utf8.length(str);
        return Utf8.sub(str, pos, len);
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
            if (e != -1)
                throw 'Invalid Utf8 stream: [...]${bytes.getString(e, got - 3)}';

            return bytes.getString(0, got);
        } catch (e:Eof) {
            return null;
        }
    }

    /*
       Read and return all records in `text`.
    */
    public static function read(text:String, ?separator=",", ?escape="\"", ?endOfLine="\n"):Array<Record>
    {
        var p = new Utf8Reader(separator, escape, endOfLine);
        p.buffer = text;
        return p.readAll();
    }
}

