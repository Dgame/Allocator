module Allocator.shared_ptr;

debug import std.stdio;

private:

struct SharedData(T) {
public:
	T* ptr;
	int usage;
	void function(T*) dealloc;
	
	@disable
	this(this);
	
	@disable
	void opAssign(SharedData!T);
}

public:

struct shared_ptr(T) {
private:
	static if (is(T : U*, U)) {
		alias Type = U;
	} else {
		alias Type = T;
	}
	
	SharedData!(Type)* _data;
	
public:
	//@disable
	//this();
	
	@disable
	this(typeof(null));
	
	this(Type* ptr, void function(Type*) dealloc) {
		this._data = new SharedData!Type(ptr, 1, dealloc);
	}
	
	this(this) {
		this._data.usage += 1;
	}
	
	~this() {
		if (!this._data)
			return;
		
		this._data.usage--;
		
		if (this._data.usage <= 0) {
			this.release();
			
			.destroy(this._data);
			this._data = null;
			
			debug writeln("DTor shared_ptr");
		}
	}
	
	void opAssign(shared_ptr!T rhs) {
		if (!rhs.isValid())
			throw new Exception("Does not accept invalid shared_ptr.");
		
		if (this._data is null)
			this._data = rhs._data;//new Data!Type(rhs._data.ptr, rhs._data.usage, rhs._data.dealloc);
		else
			throw new Exception("Cannot reassign valid shared_ptr. Use 'reset' instead.");
		
		rhs._data.usage++;
	}
	
	void reset(Type* ptr, bool release = true) {
		if (this._data is null)
			throw new Exception("Cannot reset invalid shared_ptr.");
		
		if (release)
			this.release();
		
		this._data.ptr = ptr;
	}
	
	void release() {
		if (this._data && this._data.ptr) {
			debug writeln("Release shared_ptr");
			
			this._data.dealloc(this._data.ptr);
			this._data.ptr = null;
			this._data.usage = 0;
		}
	}
	
	void swap(ref shared_ptr!T rhs) pure {
		if (!rhs.isValid() || !this.isValid())
			throw new Exception("One (or both) of the swapping shared_ptr is invalid.");
		
		Type* ptr = this._data.ptr;
		
		this._data.ptr = rhs._data.ptr;
		rhs._data.ptr = ptr;
	}
	
	void function(Type*) getDestructionFunction() const pure nothrow {
		return this._data ? this._data.dealloc : null;
	}
	
	@property
	int usage() const pure nothrow {
		return this._data ? this._data.usage : 0;
	}
	
	bool isValid() const pure nothrow {
		return this._data !is null && this._data.ptr !is null;
	}
	
	bool isRaw() const pure nothrow {
		if (!this._data)
			return false;
		
		return this._data.ptr is null;
	}
	
	@property
	inout(Type)* ptr() inout {
		return this._data.ptr;
	}
	
	alias ptr this;
}

shared_ptr!T make_shared(T)(T* ptr, void function(T*) dealloc) if (!is(T : U*, U)) {
	return shared_ptr!T(ptr, dealloc);
}

shared_ptr!T make_shared(T : U*, U)(U* ptr, void function(U*) dealloc) {
	return shared_ptr!T(ptr, dealloc);
}
