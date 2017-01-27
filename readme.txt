Questions:
	- Describe an algorithm to predict the ranking that a user U would give to a movie M assuming the user hasn’t already ranked the movie in the dataset.

	Off the top of my head (without factoring any other data into this, like genre, release date, etc): find the top x most similar users to U that have seen M, average their ratings (each given a weight based on how similar they are to U) and use that as an estimate.	

	- Does your algorithms scale? What factors determine the execution time of your “most_similar” and “popularity_list” algorithms.
	
	Popularity_list is decently fast; it runs in N time, where N is the number of elements in the hash_by_movie variable. While a call to popularity(movie_id) is made here, that hardly matters as it runs in O(1) time (popularity is defined in its purest sense -- the number of people who have seen a movie determines its popularity. As is, often unfortunately, the case in life, quality has little bearing on popularity. For further evidence of this, see the sales number of films like The Last Airbender (>319M) or Transformers: Revenge of the Fallen (>402M) then see their scores on aggregate sites like Rotten Tomatoes (6% and 19%, respectively)).

	By contrast, my similar_to(u) function scales...uh... badly. It runs in O(LMN) complexity (L = | hash_by_user |, M = | hash_by_user[smaller_user]| and N = | hash_by_user[larger_user] | ). Hopefully, with a bit more time and a bit less getting-to-know Ruby hang-ups, a less time-intensive algorithm can be formulated. 