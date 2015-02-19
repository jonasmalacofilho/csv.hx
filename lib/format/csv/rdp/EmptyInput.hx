package format.csv.rdp;

class EmptyInput extends haxe.io.Input {
    public function new() {}

    override public function readByte():Int
    {
        throw new haxe.io.Eof();
    }
}

