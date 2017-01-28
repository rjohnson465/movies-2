require 'byebug'
require 'set'
class MovieData

  attr_accessor :test_set_users, :test_set_movies
  attr_accessor :train_set_users, :train_set_movies
  attr_accessor :test_data

  # constructor
  def initialize(dataset=nil)
    # if user is nil, load in u.data as training set and empty set for test set
    if (dataset == nil)
      @train_set_users = MovieData.load_data('ml-100k/u.data', 'users')
      @train_set_movies = MovieData.load_data('ml-100k/u.data', 'movies')
      @test_set_users = Hash.new()
      @test_set_movies = Hash.new()
    else
      dataset = dataset.to_s
      @test_data = 'ml-100k/' + dataset + '.test'
      @test_set_users = MovieData.load_data('ml-100k/' + dataset + '.test', 'users')
      @test_set_movies = MovieData.load_data('ml-100k/' + dataset + '.test', 'movies')
      @train_set_users = MovieData.load_data('ml-100k/' + dataset + '.base', 'users')
      @train_set_movies = MovieData.load_data('ml-100k/' + dataset + '.base', 'movies')
    end

  end

  # read in data from ml-100k files for training/test sets (keys = users)
  def self.load_data(filename, keys)
    hash = Hash.new()
    File.foreach(filename) do |line|
      line_arr = line.split(' ')
      user_id = line_arr[0].to_i
      movie_id = line_arr[1].to_i
      rating = line_arr[2].to_i
      subhash = Hash.new()
      if (keys == 'users')
        subhash = {'movie_id'=> movie_id, 'rating'=> rating}
      else
        subhash = {'user_id'=> user_id, 'rating'=> rating}
      end
      key = (keys == "users") ? user_id : movie_id
      # store data s.t. hash keys are 'keys' (either users or movies)
      if hash[key] == nil
        hash[key] = Array.new()
      end
      hash[key].push(subhash)
    end
    return hash
  end

  # returns the rating user u gave movie m in the training set; 0 if user u did not rate movie m
  def rating(u, m)
    hashes_arr = train_set_users[u]
    hashes_arr.each do |hash|
      if (hash["movie_id"] == m)
        return hash["rating"]
      end
    end
    return 0
  end

  # returns the array of movies that user u has watched
  def movies(u)
    hashes_arr = train_set_users[u]
    movies_arr = Array.new()
    hashes_arr.each do |hash|
      movie = hash["movie_id"]
      movies_arr.push(movie)
    end
    return movies_arr
  end

  # returns array of users that have seen movie m
  def viewers(m)
    hash_arr = train_set_movies[m]
    arr = Array.new()
    hash_arr.each do |hash|
      arr.push(hash["user_id"])
    end
    return arr
  end

  # runs the predict method on the first k ratings in the test set
  # returns a MovieTest object containing results
  # k is optional -- if ommitted, all tests will be run
  def run_test(k=nil)
    arr = Array.new() # later passed to MovieTest constructor

    def run_predict(line, arr)
      line_arr = line.split(' ')
      user_id = line_arr[0].to_i
      movie_id = line_arr[1].to_i
      rating = line_arr[2].to_i
      predicted_rating = predict(user_id, movie_id)
      arr.push([user_id, movie_id, rating, predicted_rating])
    end

    if (k != nil)
      lines = File.foreach(test_data).first(k)
      lines.each do |line|
        run_predict(line, arr)
      end
    else
      # run test on all ratings in test set
      File.foreach(test_data) do |line|
        run_predict(line, arr)
      end
    end
    return MovieTest.new(arr)
  end

  # returns a floating point number between 1.0 and 5.0 as an estimate of what user u would give user m
  def predict(u, m)
    # check if user u has seen m; if so, just return their exact rating of m
    train_set_users[u].each do |hash|
      if (hash["movie_id"] == m)
        return hash["rating"]
      end
    end
    similarity_hash = most_similar(u)
    # Find all users who have seen m
    hashes_arr = train_set_movies[m]
    seen_m = Hash.new()
    if hashes_arr != nil
      hashes_arr.each do |hash|
        seen_m[hash["user_id"]] = hash["rating"]
      end
    else
      return 4 # if no one has seen m in the train set, just guess 4
    end

    # For every user s who has seen m, multiply their rating by their weight (similarity percentage; i.e. 50% -> 50)
    adjusted_ratings = 0 # sum of all adjusted ratings
    total_weight = 0 # sum of all weights
    seen_m.each do |user, rating|
      if (similarity_hash[user] != nil)
        weight = similarity_hash[user]
        total_weight += weight
        adjusted_rating = rating * weight
        adjusted_ratings += adjusted_rating
      end
    end
    # Divide total adjusted ratings over total weight for prediction
    if (total_weight != 0)
    prediction = adjusted_ratings / total_weight
    else
      prediction = 4 # if we're about to divde by 0, just guess 4
    end
    return prediction
  end

  # return a percentage which indicates the similarity in movie preference between user1/user2
  def similarity(user1, user2)
    similarity = 0
    # iterate over each movie of user with smaller data set
    # if user with larger data set has movie, check if user1's rating == user2's rating (+ or - 1)
    smaller_user = (train_set_users[user1].length < train_set_users[user2].length) ? user1 : user2
    larger_user = (smaller_user == user1) ? user2 : user1
    train_set_users[smaller_user].each do |h1|
      movie_id_smaller = h1["movie_id"]
      movie_rating_smaller = h1["rating"]

      train_set_users[larger_user].each do |h2|

        movie_id_larger = h2["movie_id"]
        movie_rating_larger = h2["rating"]

        # if both users have seen the same movie, increase similarirty based on the differential between user1 and user2's ratings
        if movie_id_smaller == movie_id_larger #&& similar_ratings
          rating_diff = (movie_rating_larger - movie_rating_smaller).abs
          sim_quotient = (movie_rating_larger - rating_diff).abs / 4 # 4 is the max differential (5-1 = 4)
          similarity += sim_quotient
        end
      end
    end


    # get total number of movies for the user with the smaller data set
    smaller_user_movies_watched = train_set_users[smaller_user].length.to_f
    # divide raw similarity score over total number of movies for the user with the smaller data set and * by 100 to get a percentage
    return (similarity / smaller_user_movies_watched) * 100
  end

  # return hash (not a list, for the purpose of preserving similarity percentages) of users whose tastes are most similar to tastes of user u
  # two approaches here (1 commented out) APPROACH ONE IS VERY VERY SLOW -- why? We are checking the similarity of u and EVERY SINGLE OTHER user -- that's 943 (for dataset u1) runs of similarity()
  def most_similar(u)
    similarity_hash = Hash.new()
    beginning_time = Time.now
    # APPROACH TWO get similarity scores only for u and top 100 users who have seen many movies that u has seen
    # make hash sim_users s.t. key = user s, value = # of movies user s has seen that user u has seen
    movies_u = movies(u)
    sim_users = Hash.new()
    movies_u.each do |movie|
      viewers(movie).each do |user|
        if (sim_users[user] == nil)
          sim_users[user] = 0
        end
        sim_users[user] += 1
      end
    end

    # use 100 users from sim_hash with the highest values ((movies in common with u)
    sim_users = sim_users.sort_by {|k, v| v}.reverse.to_h
    length = (sim_users.length < 25) ? sim_users.length : 25
    sim_users = sim_users.first(length).to_h

    sim_users.each do |user, val|
      otherUser = user
      if otherUser != u
        similarity = similarity(u, otherUser)
        if (similarity >= 0)
          similarity_hash[otherUser] = similarity
        end
      end
    end #end APPROACH TWO
=begin
    # APPROACH ONE get similarity scores for u and every other member of the dataset (very slow, ~1200 ms per prediction)
    bt2 = Time.now
    # if we reduce number of similarity calculations this would be much faster
    train_set_users.each do |key, _array|
      otherUser = key
      if otherUser != u
        similarity = similarity(u, otherUser)
        if (similarity >= 0)
          similarity_hash[otherUser] = similarity
        end
      end
    end # end APPROACH ONE
=end
    end_time = Time.now
    puts "Most similar function took #{(end_time - beginning_time)*1000} milliseconds to run"

    return similarity_hash.sort_by {|_k, v| v}.reverse.to_h
  end
end # end MovieData class


class MovieTest

  attr_accessor :data

  def initialize(data)
    @data = data
  end

  # returns the average prediction error
  def mean()
    total_diff = 0
    data.each do |arr|
      predicted = arr[3].to_f
      actual = arr[2].to_f
      differential = (predicted - actual).abs
      total_diff += differential
    end
    return total_diff / data.length
  end

  # returns the standard deviation of the error
  def stddev()

  end

  # returns the root mean square error of the prediction
  def rms()
    sum_diff_squares = 0
    data.each do |arr|
      predicted = arr[3].to_f
      actual = arr[2].to_f
      diff_squared = (actual - predicted) ** 2
      sum_diff_squares += diff_squared
    end
    frac = sum_diff_squares / data.length
    return Math.sqrt(frac)
  end

  # returns an array of the predictions in the form of [u,m,r,p]
  def to_a()
    return data
  end

end

sample_size = 100
md = MovieData.new(:u1)
mt = md.run_test(sample_size)

puts "Sample Size: #{sample_size}"
puts "Mean Error: #{mt.mean}"
puts "Standard Deviation: #{mt.stddev}"
puts "Root Mean Square Error: #{mt.rms}"
