module Allocator.List;

private {
	debug import std.stdio;
	import std.math : log2;
	import core.stdc.string : memcpy;
	
	import Allocator.MemoryPool;
	import Allocator.shared_ptr;
}

struct List(T) {
private:
	shared_ptr!(T*) _shared;
	
	void _init() {
		if (!this._shared.isValid()) {
			this._shared = make_shared!(T*)(MemoryPool.allocate!T(4), &MemoryPool.deallocate!T);
		}
	}
	
public:
	this(size_t size) {
		this._shared = make_shared!(T*)(MemoryPool.allocate!T(size), &MemoryPool.deallocate!T);
	}
	
	static if (is(T == struct)) {
		~this() {
			if (this._shared.usage <= 1) {
				const size_t length = MemoryPool.getLength(ptr);
				
				for (size_t i = 0; i < length; ++i) {
					.destroy(ptr[i]);
				}
			}
		}
	}
	
	void reserve(size_t size) {
		T* ptr = MemoryPool.reallocate!T(this._shared.ptr, size);
		
		this._shared.reset(ptr, false);
	}
	
	void reserveUntil(size_t size) {
		const long diff = this.capacity - this.length;
		//		writeln("Diff: ", diff, ", Size: ", size);
		if (diff > size)
			return;
		
		size -= diff;
		T* ptr = MemoryPool.reallocate!T(this._shared.ptr, size);
		
		this._shared.reset(ptr, false);
	}
	
	void opOpAssign(string op : "~", U : T)(auto ref U item) {
		if (!this._shared.isValid())
			this._init();
		
		MemoryPool.Data* data = MemoryPool.getData(this._shared.ptr);
		assert(data !is null);
		
		if (data.length == data.capacity) {
			if (data.capacity > 100) {
				const float percent = log2(data.capacity) / 10f;
				
				this.reserve(cast(size_t)(data.capacity * percent));
			} else
				this.reserve(cast(uint)(data.capacity * 1.4f));
		}
		
		static if (is(T == struct))
			memcpy(&this._shared.ptr[data.length], &item, T.sizeof);
		else
			this._shared.ptr[data.length] = item;
		
		data.length++;
	}
	
	ref T opIndex(size_t index) {
		if (!this._shared.isValid())
			throw new Exception("Null array.");
		
		return this._shared.ptr[index];
	}
	
	ref const(T) opIndex(size_t index) const {
		if (!this._shared.isValid())
			throw new Exception("Null array.");
		
		return this._shared.ptr[index];
	}
	
	inout(T)[] opSlice() inout {
		return this._shared.isValid() ? this._shared.ptr[0 .. this.length] : null;
	}
	
	inout(T)[] opSlice(size_t ia, size_t ib) inout {
		return this._shared.isValid() ? this._shared.ptr[ia .. ib] : null;
	}
	
	void opSliceAssign(U : T)(auto ref U item) {
		this._shared.ptr[0 .. this.length] = item;
	}
	
	void opSliceAssign(U : T, uint n)(U[n] item) {
		const size_t len = this.length;
		
		for (size_t i = 0; i < len; i += n) {
			this._shared.ptr[i .. n] = item;
		}
	}
	
	void opSliceAssign(U : T)(auto ref U item, size_t ia, size_t ib) {
		this._shared.ptr[ia .. ib] = item;
	}
	
	void opSliceAssign(U : T, uint n)(U[n] item, size_t ia, size_t ib) {
		for (size_t i = ia; i < ib; i += n) {
			this._shared.ptr[i .. n] = item;
		}
	}
	
	@property
	size_t length() const {
		return this._shared.isValid() ? MemoryPool.getLength(this._shared.ptr) : 0;
	}
	
	@property
	size_t capacity() const {
		return this._shared.isValid() ? MemoryPool.getCapacity(this._shared.ptr) : 0;
	}
	
	@property
	inout(T)* ptr() inout pure nothrow {
		return this._shared.ptr;
	}
}