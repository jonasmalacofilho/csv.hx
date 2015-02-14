import haxe.Utf8;

class Utf8Parser extends Parser {
    override function substr(str:String, pos:Int, len:Int):String
    {
        return Utf8.sub(str, pos, len);
    }

    override function strlen(str:String):Int
    {
        return Utf8.length(str);
    }
}

