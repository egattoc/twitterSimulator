defmodule TwitterClient do
use GenServer

    def start_link(userNum) do
        GenServer.start_link(__MODULE__, [], name: {:via, Registry, {:twitterRegistry, userNum}})
    end

    def init(state) do
        {:ok, state}
    end

    def handle_call({:loginUser, uName, pwd}, _from, state) do
        GenServer.call(:twitterServer, {:loginUser, uName, pwd})
        {:reply, :ok, state}
    end

    def handle_call({:logoutUser}, _from, state) do
        [uName] = getUserName(self())
        GenServer.call(:twitterServer, {:logoutUser, uName})
        {:reply, :ok, state}
    end

    def handle_cast({:subscribe, userName2}, state) do #user1 subscribes to user2
        [userName1] = getUserName(self())
        GenServer.cast(:twitterServer, {:subscribeTo, userName1, userName2})
        {:noreply, state}
    end

    def handle_call({:registerUser,uName, pwd}, _from , state) do
        GenServer.call(:twitterServer,{:registerUser, uName, pwd})
        {:reply,:ok,state}
    end

    def handle_cast({:tweet,msg},state) do
        [userName] = getUserName(self())
        # IO.inspect(userName)
        GenServer.cast(:twitterServer, {:tweet, userName, msg})
        {:noreply, state}
    end

    def handle_cast({:retweet,msg},state) do
        [userName] = getUserName(self())
        GenServer.cast(:twitterServer, {:retweet, userName, msg})
        {:noreply, state}
    end

    def handle_call({:queryHashtags, ht}, _from, state) do
        listOfTweets = GenServer.call(:twitterServer,{:queryHashtags,ht})
        {:reply,listOfTweets, state}
    end

    def handle_call({:liveFeed},_from,state) do
        [userName] = getUserName(self())
        l = GenServer.call(:twitterServer,{:liveFeed,userName})
        {:reply,l,state}
    end
    
    def handle_call({:queryMentions}, _from, state) do
        [userName] = getUserName(self())
        listOfTweets =  GenServer.call(:twitterServer,{:queryMentions,userName})
        {:reply,listOfTweets, state}
    end

    def handle_call({:deleteUser}, _from , state) do
        [uName] = getUserName(self())
        GenServer.call(:twitterServer,{:deleteUser,uName})
        {:reply,:ok,state}
    end

    def getUserName(pid) do
        Registry.keys(:twitterRegistry,pid)
    end

end