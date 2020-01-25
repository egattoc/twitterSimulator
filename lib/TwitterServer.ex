defmodule TwitterServer do
use GenServer

    def start_link() do
        GenServer.start_link(__MODULE__,[], name: :twitterServer)
    end

    def init(state) do
        :ets.new(:userList, [:set, :named_table,:public])
        :ets.new(:tweetCount, [:set, :named_table,:public])
        :ets.new(:userMention, [:set, :named_table,:public])
        :ets.new(:hashTag, [:set, :named_table,:public])
        :ets.new(:tweets, [:set, :named_table,:public])
        :ets.new(:activeUser, [:set, :named_table,:public])
        :ets.new(:subscribedTo, [:set, :public, :named_table]) 
        :ets.new(:followers, [:set, :public, :named_table])
        :ets.new(:inactiveFeed, [:set, :public, :named_table])
        :ets.new(:activeFeed, [:set, :public, :named_table])
        {:ok, state}
    end

    def userExists(uName) do
        userDetail = :ets.lookup(:userList,uName)
        if userDetail == [] do
            false
        else
            true
        end
    end

    def userActive(uName) do
        userDetail = :ets.lookup(:activeUser,uName)
        if userDetail == [] do
            false
        else
            true
        end
    end

    def getFollowers(uName) do
        list = case :ets.lookup(:followers, uName) do
            [{users,followers}] -> followers
            _->[]
        end
        list
    end

    def handle_call({:queryMentions,uName}, _from , state) do
        list = case :ets.lookup(:userMention, uName) do
            [{users,tweets}] -> tweets
            _->[]
        end
        {:reply,list,state}
    end

    def handle_call({:queryHashtags,ht}, _from , state) do
        list = case :ets.lookup(:hashTag, ht) do
            [{users,tweets}] -> tweets
            _->[]
        end
        {:reply,list,state}
    end

    def handle_call({:registerUser,uName, pwd}, _from , state) do
        if (!userExists(uName)) do
            :ets.insert(:userList,{uName,pwd})
            # :ets.insert(:activeUser,{uName})
        else
            IO.puts "User #{uName} already exists"
        end
        {:reply,:ok,state}
    end

    def handle_call({:loginUser, uName, pwd}, _from , state) do
        case :ets.lookup(:userList,uName) do
            [{u,p}] when p == pwd ->
                 :ets.insert(:activeUser,{uName})
                 inactiveFeed = case :ets.lookup(:inactiveFeed,uName) do
                            [{u,f}] -> f
                            _ ->[]
                             end
                 activeFeed = case :ets.lookup(:activeFeed,uName) do
                            [{u,f}] -> f
                            _ ->[]
                            end
                 if(inactiveFeed!=[]) do
                    :ets.insert(:activeFeed,{uName,inactiveFeed++activeFeed})  
                 end
            _ -> IO.puts("User or password do not match")
        end
        {:reply,:ok,state}
    end

    def handle_call({:logoutUser, uName}, _from , state) do
        case :ets.lookup(:activeUser,uName) do
            [{u}] ->
                 :ets.delete(:activeUser,uName)
            _ -> IO.puts("User is not active")
        end
        {:reply,:ok,state}
    end

    def handle_cast({:AddHashTag, x, tweet}, state) do
        case :ets.lookup(:hashTag,x) do
            [{tag,list}] -> :ets.insert(:hashTag,{x,list ++ [tweet]})
            _ -> :ets.insert(:hashTag,{x,[tweet]})
        end
        {:noreply,state}
    end

    def handle_cast({:AddMention, x, tweet}, state) do
        case :ets.lookup(:userMention,x) do
            [{tag,list}] -> :ets.insert(:userMention,{x,list ++ [tweet]})
            _ -> :ets.insert(:userMention,{x,[tweet]})
        end
        {:noreply,state}
    end

    def handle_call({:deleteUser,uName}, _from , state) do
        :ets.delete(:userList,uName)
        :ets.delete(:activeUser,uName)
        {:reply,:ok,state}
    end

    def handle_cast({:subscribeTo, userName1, userName2},state) do
        case :ets.lookup(:subscribedTo,userName1) do
            [{u,l}] -> :ets.insert(:subscribedTo,{userName1,l ++ [userName2]})
            _ -> :ets.insert(:subscribedTo,{userName1,[userName2]})
        end
        case :ets.lookup(:followers,userName2) do
            [{u,l}] -> :ets.insert(:followers,{userName2,l ++ [userName1]})
            _ -> :ets.insert(:followers,{userName2,[userName1]})
        end
        {:noreply,state}
    end

    def handle_cast({:tweet, userName, tweet},state) do
        # IO.inspect("Entered Server")
        # tweetid = System.unique_integer [:monotonic,:positive]
        case :ets.lookup(:tweets,userName) do
            [{u,l}] -> :ets.insert(:tweets,{userName,[tweet] ++ l})
            _ ->  :ets.insert(:tweets,{userName,[tweet]})
        end
        # IO.inspect(:ets.lookup(:tweets,userName))
        followers = getFollowers(userName)
        mentionedList = parseTweet(tweet)
        distribute = Enum.uniq(followers ++ mentionedList)
        # IO.inspect(followers)
        activeFollowers = Enum.filter(distribute, fn x->userActive(x) end)
        # IO.inspect(activeFollowers)
        inactiveFollowers = Enum.filter(distribute, fn x->!userActive(x) end)
        # IO.inspect(inactiveFollowers)
        Enum.each(activeFollowers,fn x->addActiveFeed(x,userName,tweet) end)
        # IO.inspect(:ets.lookup(:activeFeed,"User1"))
        
        Enum.each(inactiveFollowers, fn x-> addInactiveFeed(x,userName,tweet) end)
        {:noreply,state}
    end

    def handle_call({:liveFeed, userName},_from,state) do
        l = case :ets.lookup(:activeFeed,userName) do
            [{u,t}] -> t
            _ -> []
        end
        {:reply,l,state}
    end

    def handle_cast({:retweet, userName, tweet},state) do
        case :ets.lookup(:tweets,userName) do
            [{u,l}] -> :ets.insert(:tweets,{userName,[tweet] ++ l})
            _ -> :ets.insert(:tweets,{userName,[tweet]})
        end
        followers = getFollowers(userName)
        activeFollowers = Enum.filter(followers, fn x->userActive(x) end)
        inactiveFollowers = Enum.filter(followers, fn x->!userActive(x) end)
        Enum.each(activeFollowers,fn x-> addActiveFeed(x,userName,tweet) end)
        Enum.each(inactiveFollowers, fn x-> addInactiveFeed(x,userName,tweet) end)
        {:noreply,state}
    end

    def addActiveFeed(userName, from, tweet) do
        case :ets.lookup(:activeFeed, userName) do
            [{user,feed}] -> :ets.insert(:activeFeed, {userName,[[from,tweet]] ++ feed})
            _ -> :ets.insert(:activeFeed, {userName,[[from,tweet]]})
        end
    end

    def addInactiveFeed(userName, from,tweet) do
        case :ets.lookup(:inactiveFeed, userName) do
            [{user,feed}] -> :ets.insert(:inactiveFeed, {userName,[[from,tweet]] ++ feed})
            _ -> :ets.insert(:inactiveFeed, {userName,[[from,tweet]]})
        end
    end

    def parseTweet(tweet) do
        hashTagRegex = ~r(\B#[a-zA-Z1-9]+\b)
        listOfHashTags = Regex.scan(hashTagRegex, tweet) |> List.flatten()

        userMentionsRegex = ~r(\B@[a-zA-Z1-9]+\b)
        listOfUserMentions = Regex.scan(userMentionsRegex, tweet) |> List.flatten()

        mentionedUserList=Enum.map(listOfUserMentions,fn(x)-> String.slice(x,1..String.length(x)) end)
        
        if length(listOfHashTags) > 0 do
            Enum.each(listOfHashTags, fn(x) -> GenServer.cast(:twitterServer, {:AddHashTag, x, tweet}) end)
        end
        
        if length(mentionedUserList) > 0 do
            Enum.each(mentionedUserList, fn(x) -> GenServer.cast(:twitterServer, {:AddMention, x, tweet}) end)
        end
        mentionedUserList
    end

end