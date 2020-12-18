%% Author:	Robert Balogh
%% Company:	Ericsson Hungary Ltd.
%% Description:	Under construction :-)


-module(fileHandling).

-export([
		 openFile/2,
		 closeFile/1,
		 
		 copyFile/2,
		 deleteFile/1,
		 renameFile/2,
		 createFile/1,
		 
		 writeLine/2,
		 readLine/2,
		 
		 readFile/1
		]).

%%-----------------------------------------------------------------------------------------
%% This function will be create a new file.
%% Imput:	FileName		-	string
%%			OperationType	-	type of the operation	atom	open/write/append
%% Output:
%%		{ok, Id} | {error, Reason}
%%-----------------------------------------------------------------------------------------
openFile(FileName,OperationType)->
	Result = file:open(FileName,[OperationType]),
	
	case Result of
		{ok,IoDevice} ->
			%% The file has been opened. IoDevice is a reference to the file.
			{ok,IoDevice};
		
		{error, Reason}	->
			%% The file could not be opened.
			{error, Reason}
	end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be create a new file.
%%-----------------------------------------------------------------------------------------
closeFile(IoDevice)->
	file:close(IoDevice).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be to copy the file.
%%-----------------------------------------------------------------------------------------
copyFile(SourceName,DestinationName)->
	file:copy(SourceName,DestinationName).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be to delete the file.
%%-----------------------------------------------------------------------------------------
deleteFile(FileName)->
	file:delete(FileName).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be to rename the file.
%%-----------------------------------------------------------------------------------------
renameFile(SourceName,DestinationName)->
	file:rename(SourceName,DestinationName).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be create a new file.
%%-----------------------------------------------------------------------------------------
createFile(_FileName)->
	{}.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be to write a new line into the "FileName".
%%-----------------------------------------------------------------------------------------
writeLine(IoDevice,String)->
	case String of
		[]	->
			io:format(IoDevice, "~n", []);
		_->
			%% Get length of the string
			io:format(IoDevice, String, [])
	end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be to read the "FileName". (all lines)
%% Output: List of the lines
%%-----------------------------------------------------------------------------------------
readFile(FileName)->
	Result = openFile(FileName,read),
	
	case Result of
		{ok,IoDevice} ->
			%% The file has been opened. IoDevice is a reference to the file.
			ResultList = readFileLoop(IoDevice,[]),
			closeFile(IoDevice),
			ResultList;
		
		{error, _Reason} ->
			%% The file could not be opened.
			Result = []
	end.

readFileLoop(IoDevice,ResultList)->
	ReadString = readLine(IoDevice,[]),
	case ReadString of
		eof	->	%% End of file
			lists:reverse(ResultList);
		
		_Str -> 
			case ReadString == [] of
				true ->
					%% ReadString is empty. Do nothing!!
					readFileLoop(IoDevice,ResultList);
				
				false ->
					%% ReadString is not empty
					TempList = string:tokens(ReadString," "),
					case TempList of
						[] ->
							readFileLoop(IoDevice,ResultList);
						_->
							Head = lists:nth(1,TempList), 
								case Head of
									"##"->
										%% This is a comment. Not need to put in the ResultList.
										readFileLoop(IoDevice,ResultList);
									_->	readFileLoop(IoDevice,[ReadString | ResultList])
								end
					end
			end
	
	end.	
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be to read a line from the IoDevice (FileName). Read one by one the char
%% until \n char. The result string is not contains the \n char. ReadString is contains the result string.
%%-----------------------------------------------------------------------------------------
readLine(IoDevice,ReadString)->
	case io:get_chars(IoDevice,'',1) of
		eof	->	%% End of file
			eof;
		
		Str	->
			case Str of
				"\n" ->
					%% End of char
					ReadString;
				"\t" ->
					%% TAB, need to change with 4 space
					readLine(IoDevice,ReadString++"    ");
				_->	%% Any other char
					readLine(IoDevice,ReadString++Str)
			end
	end.
%%----- End of function -------------------------------------------------------------------
