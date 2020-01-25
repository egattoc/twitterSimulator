defmodule Twitter do
  use GenServer
  @messageList ["Sample message", "Sample only # message","Sample only User mention @ ","Sample # and User mention @ message"]
  @hashtagList ["#me2","#project4","#UFL","#Gainesville","#MakeUSAGreatAgain"]

  def start_link() do
    GenServer.start_link(__MODULE__,[],name: :twitter)
  end

  def init(state) do
    {:ok,state}
  end

  def createSimulation(numUsers,numTweet) do
    Registry.start_link(keys: :unique, name: :twitterRegistry)
    TwitterServer.start_link()

    userList = Enum.map(1..numUsers, fn x -> "User" <> Integer.to_string(x) end)
    
    # Registering number of clients as per input argument
    Enum.each(userList, fn(userName) -> {:ok, pid} = TwitterClient.start_link(userName)
                                        GenServer.call(pid, {:registerUser, userName,"1234"})
                                        GenServer.call(pid, {:loginUser,userName,"1234"}) end
                                        )

    # time calculation for generating n/2 followers                                        
    # start_time = System.system_time(:millisecond)
    generateFollowers(userList)
    # time_difference = System.system_time(:millisecond) - start_time

    # IO.inspect(time_difference)   --- Used for performance - commented since no output required
    :timer.sleep(1000)
    
    # time calculation for sending number of tweets as per input
    # start_time = System.system_time(:millisecond)
    Enum.each(1..numTweet, fn(count) -> sendTweets(userList,numUsers) end)
    # time_difference = System.system_time(:millisecond) - start_time
    # IO.inspect(time_difference)
  end

  def sendTweets(userList,numUsers) do
    Enum.each(userList, fn uName -> msg = generateMessage(userList,uName)
                        GenServer.cast(getPid(uName),{:tweet,msg}) end)
  end

  def getPid(userName) do
    elem(hd(Registry.lookup(:twitterRegistry, userName)),0)
  end

  def generateFollowers(userList) do
    num = length(userList)
    Enum.each(0..num-1, fn x-> name = Enum.at(userList,x);
                                          subscribeToList = Enum.take_random(userList,round(num/2))|>Enum.filter(fn y-> y != name end)
                                          Enum.each(subscribeToList,fn y-> GenServer.cast(getPid(name),{:subscribe, y}) end)
          end
      )
  end

  def generateMessage(userList,userId) do
    randomMsgs = Enum.random(@messageList) 
    randomHashTag = Enum.random(@hashtagList)
    randomUser = Enum.random(userList--[userId])
    tweet = String.replace(randomMsgs,"#",randomHashTag)
    tweet = String.replace(tweet,"@","@"<>randomUser)
    tweet
  end
end