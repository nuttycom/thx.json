FROM imsky/haxe

RUN haxelib --global install hmm 1.3.0
RUN haxelib --global run hmm setup
