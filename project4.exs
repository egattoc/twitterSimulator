defmodule Project4 do
  def start() do
      [users, tweets] = System.argv()
      Twitter.start_link()
      Twitter.createSimulation(String.to_integer(users),String.to_integer(tweets))
  end        
end

Project4.start()