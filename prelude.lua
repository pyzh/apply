local null={}
local pairt={}
local vectort={}
local symbolt={}
local void={}
local atomt={}
local promiset={}
local linebuff=""
local function newline()print(linebuff)linebuff=""end
local function putstr(s)linebuff=linebuff..s end
local function add(x,y)return x+y end
local function sub(x,y)return x-y end
local function mul(x,y)return x*y end
local function quo(x,y)return x/y end
local function or2(x,y)return x or y end
local function and2(x,y)return x and y end
local function notf(x)return not x end
local function is_null(x)return x==null end
local function is_table(x)return type(x)=="table"end
local function is_string(x)return type(x)=="string"end
local function is_procedure(x)return type(x)=="function"end
local function is_number(x)return type(x)=="number"end
local function is_boolean(x)return type(x)=="boolean"end
local function is_pair(x)return(is_table(x)and x[1]==pairt)end
local function cons(x,y)return{pairt,x,y}end
local function car(x)assert(is_pair(x))return x[2]end
local function cdr(x)assert(is_pair(x))return x[3]end
local function list(...)
	local xs={...}
	local r=null
	for i=#xs,1,-1 do
		r=cons(xs[i],r)
	end
	return r
end
local function is_list(x)return is_null(x)or(is_pair(x)and is_list(cdr(x)))end
local function vector(...)return{vectort,{...}}end
local function is_vector(x)return(is_table(x)and x[1]==vectort)end
local function vector_ref(x,n)
	assert(is_vector(x))
	local r=x[2][n+1]
	assert(r~=nil)
	return r
end
local function symbol(x)assert(is_string(x))return{symbolt,x}end
local function is_symbol(x)return(is_table(x)and x[1]==symbolt)end
local function sym2str(x)assert(is_symbol(x))return x[2]end
local function voidf()return void end
local function is_void(x)return x==void end
local function ig(x)end
local equal=nil
local function veceq(x,y)
	if #x ~= #y then return false end
	for i=1,#x do
		if not equal(x[i],y[i]) then return false end
	end
	return true
end
equal=function(x,y)
	if x==y then return true end
	if not (is_table(x)and is_table(y))then return false end
	local t=x[1]
	if t~=y[1] then return false end
	if t==pairt then
		return equal(x[2],y[2]) and equal(x[3],y[3])
	elseif t==symbolt then
		return x[2]==y[2]
	elseif t==vectort then
		return veceq(x[2],y[2])
	end
	return false
end
local function atom(x)return{atomt,x}end
local function is_atom(x)return(is_table(x)and x[1]==atomt)end
local function atom_set(a,v)assert(is_atom(a))a[2]=v return void end
local function atom_map(a,f)assert(is_atom(a))a[2]=f(a[2])return void end
local function atom_get(a)assert(is_atom(a))return a[2]end
local function eq(x,y)return x==y end
local function gt(x,y)return x>y end
local function lt(x,y)return x<y end
local function gteq(x,y)return x>=y end
local function lteq(x,y)return x<=y end
local function is_promise(x)return(is_table(x)and x[1]==promiset)end
local function force(x)
	if x[3]==nil then
		x[3]=x[2]()
		x[2]=nil
	end
	return x[3]
end
local function write(x)
	if x==null then
		putstr("()")
	elseif x==void then
		putstr("#<void>")
	elseif is_string(x) then
		putstr("\"")
		putstr(x)
		putstr("\"")
	elseif is_number(x) then
		putstr(tostring(x))
	elseif is_boolean(x) then
		if x then
			putstr("#t")
		else
			putstr("#f")
		end
	elseif is_list(x) then
		local xs=cdr(x)
		putstr("(")
		write(car(x))
		while not is_null(xs) do
			putstr(" ")
			write(car(xs))
			xs=cdr(xs)
		end
		putstr(")")
	else
		if not is_table(x)then return putstr(tostring(x)) end
		local t=x[1]
		if t==pairt then
			putstr("(")
			write(car(x))
			putstr(" . ")
			write(cdr(x))
			putstr(")")
		elseif t==symbolt then
			putstr("'")
			putstr(sym2str(x))
		elseif t==vectort then
			putstr("#(")
			local t=x[2]
			if t[1]~=nil then write(t[1])end
			for i=2,#t do
				putstr(" ")
				write(t[i])
			end
			putstr(")")
		elseif t==atomt then
			putstr("#<atom!")
			putstr(atom_get(x))
			putstr(">")
		elseif t==promiset then
			if x[3]==nil then
				putstr("#<promise>")
			else
				putstr("#<promise!")
				putstr(x[3])
				putstr(">")
			end
		else
			putstr("#<table")
			for k,v in pairs(x) do
				putstr("(")
				write(k)
				putstr(" ")
				write(v)
				putstr(")")
			end
			putstr(">")
		end
	end
end
local function writeln(x)write(x)newline()end
local errorv=nil
local serr="SchemeError"
local function raise(x)errorv=x error(serr)end
local function spcall(x,f)
	local s,r=pcall(x)
	if s then
		return r
	elseif string.sub(r,-#serr)==serr then
		local v=errorv
		errorv=nil
		return f(v)
	else
		error(r)
	end
end
local function list2lua(xs)
	local t={}
	local xs=xs
	while not is_null(xs) do
		t[#t+1]=car(xs)
		xs=cdr(xs)
	end
	return t
end
local function apply(f,xs)
	return f(unpack(list2lua(xs)))
end
local toscm=nil
local function scmto(x)
	if x==void then
		return nil
	elseif is_list(x) then
		local t=list2lua(x)
		for i=1,#t do
			t[i]=scmto(t[i])
		end
		return t
	elseif x==null or is_pair(x) then
		error("NULL/PAIR!")
	elseif is_vector(x) then
		local t=sym2str(vector_ref(x,0))
		if t=="_v" then
			local v=x[2]
			local r={}
			for i=2,#v do
				r[i-1]=scmto(v[i])
			end
			return r
		elseif t=="hashv" then
			local v=vector_ref(x,1)
			local r={}
			while not is_null(v) do
				local x=car(v)
				local k=tostr(car(x))
				if r[k]==nil then
					r[k]=scmto(cdr(x))
				end
				local v=cdr(v)
			end
			return r
		else
			error("STRUCT!")
		end
	elseif is_symbol(x) then
		return sym2str(x)
	elseif is_atom(x) then
		return scmto(atom_get(x))
	elseif is_promise(x) then
		return scmto(force(x))
	elseif is_procedure(x) then
		return function(...)
				local xs={...}
				for i=1,#xs do
					xs[i]=toscm(xs[i])
				end
				return scmto(x(unpack(xs)))
				end
	else
		return x
	end
end
local function is_table_list(v)
	for i, v in pairs(v) do
		if type(i) ~= "number" then
			return false
		end
	end
	return true
end
toscm=function(x)
	if x==nil then
		return void
	elseif is_table(x) then
		if is_table_list(x) then
			return list(unpack(x))
		else
			local r=null
			for k,v in pairs(x) do
				r=cons(cons(symbol(tostring(x)),toscm(v)),r)
			end
			return vector(symbol("hashv"),r)
		end
	elseif is_procedure(x) then
		return function(...)
				local xs={...}
				for i=1,#xs do
					xs[i]=scmto(xs[i])
				end
				return toscm(x(unpack(xs)))
				end
	else
		return x
	end
end
local function string2list(s)
	local r={}
	for i=1,#s do
		r[i]=str:sub(i,i)
	end
	return list(unpack(r))
end
local function is_char(x)return is_string(x)and#x==1 end

