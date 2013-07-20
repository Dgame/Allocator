module main;

import std.stdio;

import Allocator.List;
import Allocator.shared_ptr;
import Allocator.MemoryPool;

struct A {
public:
	int id;
	
	this(int id) {
		this.id = id;
	}
	
	~this() {
		writeln("DTor von A: ", this.id);
	}
}

final abstract class Memory {
public:
	static void foo(A* ptr) {
		writeln("foo");
		ptr = null;
	}
}

class B {
public:
	int id;
	
	this(int id) {
		this.id = id;
	}
}

void main() {
	List!int liste;
	
	writeln(liste.length, "::", liste.capacity);
	
	liste ~= 42;
	
	writeln(liste.length, "::", liste.capacity);
	
	liste ~= 23;
	
	writeln(liste.length, "::", liste.capacity);
	
	liste ~= 24;
	
	writeln(liste.length, "::", liste.capacity);
	
	foreach (int i; 1 .. 1_000_000) {
		liste ~= i;
		//		writeln(liste.length, "::", liste.capacity);
	}
	
	writeln(liste.length, "::", liste.capacity);
	
	//	writeln(MemoryPool.getReallocations(liste.ptr));
	//	writeln(MemoryPool.getMovements(liste.ptr));
	//	
	liste.reserveUntil(1000);
	
	writeln(" -> ", liste.length, "::", liste.capacity);
	
	//	writeln(MemoryPool.getReallocations(liste.ptr));
	//	writeln(MemoryPool.getMovements(liste.ptr));
	
	writeln("----");
	
	{
		shared_ptr!A sa = make_shared(new A(42), &Memory.foo);
		writeln("1 == ", sa.usage);
		writeln("42 == ", sa.id);
		{
			shared_ptr!A sa1 = sa;
			writeln("2 == ", sa.usage);
			writeln("2 == ", sa1.usage);
			writeln("42 == ", sa.id);
			writeln("42 == ", sa1.id);
		}
		writeln("1 == ", sa.usage);
		writeln("42 == ", sa.id);
	}
	
	writeln("----");
	
	A* at = MemoryPool.emplace!A(23);
	writeln(at.id, " => ", MemoryPool.getCapacity(at), "::", MemoryPool.getLength(at));
	//	MemoryPool.reallocate(at, 12);
	
	//	B* bt = MemoryPool.emplace!B(1337);
	//	writeln(bt.id);
	{
		List!A alist;
		alist ~= A(4223);
		{
			writeln(" => ", alist[0].id);
		}
		writeln(" -> Destroy A List");
	}
}

