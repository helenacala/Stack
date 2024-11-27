# throughout the code i am calling the stack a linked list. this is because a stack is exactly like a linked list.

module Stack


# greet() = print("Hello World, this is the actual stack folder/file")

#creating a structure for what the nodes should look like. Contains generic types. 
struct Node{T}
	data     :: T
	nextNode :: Union{Node, Nothing}
end

#making a structure of what the linked list should be like. can have a tail and head. Tail is not used as much. 
struct LinkedList
	head:: Union{Node, Nothing}
	tail :: Union{LinkedList, Nothing}
end

#push method
function push(x::LinkedList, y::Node)
	tempHead = x.head

	if !isEmpty(x)
		x.head = y
		y.nextNode = tempHead
	else
		x.head = y
	end
end


#pop method
function pop(x::LinkedList) # to pop somethifg we dont need to take in a Node. just first one
	if isEmpty(x) # make a function isEmpty() becasue it does not come pre built in here.
		println("There is nothing to be popped. Stack is empty")
	else
	#return linkedlist - head
	 x.head = x.head.nextNode
	end
end


#peek method. but we may not need it. why do we need to peek????
#the peak just returns whatever is at the head? 
function peek(x::LinkedList)
	if isEmpty(x) # make a function isEmpty() becasue it does not come pre built in here.
		println("There is nothing to be seen/peaked. Stack is empty")
		#do i have to say return nothing here
	else
	#return linkedlist - head
	 return x.head.data 
	end
end


#makes a funciton to check if linkedList is empty
function isEmpty(x::LinkedList) 
	isItEmpty = false
	if x.head == nothing
		isItEmpty = true
	end
	return isItEmpty
end

#recursively prints the data of the top node and then pops it. without changing the initial stack. 
function printAllElements(x::LinkedList)
	tempLinkedList = x

	println(tempLinkedList.head)
	return printAllElements(pop(tempLinkedList))
end 

end
