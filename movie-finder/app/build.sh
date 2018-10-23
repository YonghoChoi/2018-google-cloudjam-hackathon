npm run build

docker build -t redrebel/movie-finder .

docker push redrebel/movie-finder

kubectl apply -f movie-finder.yml

 
