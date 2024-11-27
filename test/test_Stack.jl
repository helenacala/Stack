#testing the stack
using Test
using Stack
#include("Stack.jl")
#using Tes:wq


# make a new linked list

@testset "Stack.jl" begin
#declaring two nodes
	node1 = Stack.Node(1, nothing)
	node2 = Stack.Node(2, nothing)

	@test node1.data == 1
	@test node2.data == 3

	
end

#more tests to come
