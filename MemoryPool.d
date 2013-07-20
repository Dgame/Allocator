module Allocator.MemoryPool;

private {
	debug import std.stdio;
	import std.conv : emplace;
	import core.stdc.stdlib : malloc, realloc, free;
}

struct Allocator {
public:
	void* function(size_t) allocate;
	void* function(void*, size_t) reallocate;
	void  function(void*) deallocate;
	
	this(void* function(size_t) allocate, void* function(void*, size_t) reallocate, void function(void*) deallocate) {
		this.allocate   = allocate;
		this.reallocate = reallocate;
		this.deallocate = deallocate;
	}
}

struct Allocate(alias allocFunc) {
public:
	static void* allocate(size_t size) nothrow {
		return allocFunc(size);
	}
}

struct Reallocate(alias reallocFunc) {
public:
	static void* reallocate(void* ptr, size_t size) nothrow {
		ptr = reallocFunc(ptr, size);
		
		return ptr;
	}
}

struct Deallocate(alias deallocFunc) {
public:
	static void deallocate(void* ptr) nothrow {
		deallocFunc(ptr);
	}
}

final abstract class MemoryPool {
public:
	enum Mode : ubyte {
		None = 0,
		NoRealloc = 1,
		NoMove = 2
	}
	
package:
	struct Data {
	public:
		void* ptr;
		
		size_t capacity;
		size_t length;
		size_t reallocations;
		size_t movements;
		
		Mode mode;
	}
	
private:
	static Data[void*] _pool;
	static Allocator _allocator = void;
	
public:
	static this() {
		this._allocator = Allocator(
			&Allocate!malloc.allocate,
			&Reallocate!realloc.reallocate,
			&Deallocate!free.deallocate);
	}
	
	static ~this() {
		//		writeln("DTor MemoryPool");
		
		foreach (ref Data data; MemoryPool._pool) {
			MemoryPool.deallocate(data.ptr);
			.destroy(data);
		}
		
		MemoryPool._pool = null;
	}
	
	static void setAllocator(ref const Allocator allocator) {
		MemoryPool._allocator = allocator;
	}
	
	static void setAllocator(const Allocator allocator) {
		MemoryPool.setAllocator(allocator);
	}
	
	static size_t getCapacity(T)(const T* ptr) {
		if (!MemoryPool.isValid(ptr))
			return 0;
		
		return MemoryPool._pool[ptr].capacity;
	}
	
	static size_t getLength(T)(const T* ptr) {
		if (!MemoryPool.isValid(ptr))
			return 0;
		
		return MemoryPool._pool[ptr].length;
	}
	
	static Data* getData(T)(T* ptr) {
		if (!MemoryPool.isValid(ptr))
			return null;
		
		return &MemoryPool._pool[ptr];
	}
	
	static T* emplace(T, Args...)(auto ref Args args)
		if (/*is(T == class) || */is(T == struct))
	{
		static if (is(T == class))
			const size_t size = __traits(classInstanceSize, T);
		else
			const size_t size = T.sizeof;
		
		T* chunk = MemoryPool.allocate!T(size, Mode.NoRealloc);
		
		return .emplace(chunk, args);
	}
	
	static T* allocate(T)(size_t size, Mode mode = Mode.None) {
		static if (!is(T == class) && !is(T == struct))
			void* ptr = MemoryPool._allocator.allocate(size * T.sizeof);
		else
			void* ptr = MemoryPool._allocator.allocate(size);
		
		MemoryPool._pool[ptr] = Data(ptr, size);
		
		Data* d = MemoryPool.getData(ptr);
		d.mode = mode;
		
		return cast(T*) ptr;
	}
	
	static T* reallocate(T)(T* ptr, size_t size) {
		if (MemoryPool.isValid(ptr)) {
			Data* d = &MemoryPool._pool[ptr];
			
			if (d.mode & Mode.NoRealloc)
				throw new Exception("It's not allowed to extend this memory block.");
			
			d.capacity += size;
			d.ptr = MemoryPool._allocator.reallocate(d.ptr, d.capacity * T.sizeof);
			
			assert(d.ptr !is null, "Memory error.");
			
			d.reallocations++;
			
			if (d.ptr !is ptr) {
				if (d.mode & Mode.NoMove)
					throw new Exception("It's not allowed to move this memory block.");
				
				d.movements++;
				
				MemoryPool._pool[d.ptr] = *d;
				MemoryPool._pool.remove(ptr);
				
				ptr = cast(T*) d.ptr;
			}
			
			return ptr;
		}
		
		return null;
	}
	
	static void deallocate(T)(T* ptr) {
		if (ptr is null || !MemoryPool.isValid(ptr))
			return;
		
		MemoryPool._allocator.deallocate(ptr);
		//(cast(int*) ptr)[0 .. MemoryPool.getCapacity(ptr)] = 0;
		MemoryPool._pool.remove(ptr);
	}
	
	static bool isValid(T)(const T* ptr) {
		if (ptr in MemoryPool._pool)
			return true;
		
		return false;
	}
}
