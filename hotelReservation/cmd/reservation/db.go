package main

import (
	"context"
	"fmt"
	"strconv"

	"github.com/rs/zerolog/log"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Reservation struct {
	HotelId      string `bson:"hotelId"`
	CustomerName string `bson:"customerName"`
	InDate       string `bson:"inDate"`
	OutDate      string `bson:"outDate"`
	Number       int    `bson:"number"`
}

type Number struct {
	HotelId string `bson:"hotelId"`
	Number  int    `bson:"numberOfRoom"`
}

func initializeDatabase(url string) (*mongo.Client, func()) {
	log.Info().Msg("Generating test data...")

	newReservations := []interface{}{
		Reservation{"4", "Alice", "2015-04-09", "2015-04-10", 1},
	}

	newNumbers := []interface{}{
		Number{"1", 200},
		Number{"2", 200},
		Number{"3", 200},
		Number{"4", 200},
		Number{"5", 200},
		Number{"6", 200},
	}

	for i := 7; i <= 80; i++ {
		hotelID := strconv.Itoa(i)

		roomNumber := 200
		if i%3 == 1 {
			roomNumber = 300
		} else if i%3 == 2 {
			roomNumber = 250
		}

		newNumbers = append(newNumbers, Number{hotelID, roomNumber})
	}

	uri := fmt.Sprintf("mongodb://%s", url)
	log.Info().Msgf("Attempting connection to %v", uri)

	opts := options.Client().ApplyURI(uri)
	client, err := mongo.Connect(context.TODO(), opts)
	if err != nil {
		log.Panic().Msg(err.Error())
	}
	log.Info().Msg("Successfully connected to MongoDB")

	database := client.Database("reservation-db")
	resCollection := database.Collection("reservation")
	numCollection := database.Collection("number")

	// The reservation collection also receives runtime bookings, so it gets
	// no unique index; the single seed row is upserted instead.
	seedRes := newReservations[0].(Reservation)
	_, err = resCollection.ReplaceOne(context.TODO(),
		bson.D{{"hotelId", seedRes.HotelId}, {"customerName", seedRes.CustomerName}},
		seedRes, options.Replace().SetUpsert(true))
	if err != nil {
		log.Fatal().Msg(err.Error())
	}

	err = seedCollection(numCollection, bson.D{{"hotelId", 1}}, newNumbers)
	if err != nil {
		log.Fatal().Msg(err.Error())
	}
	log.Info().Msg("Successfully inserted test data into reservation DB")

	return client, func() {
		if err := client.Disconnect(context.TODO()); err != nil {
			log.Fatal().Msg(err.Error())
		}
	}
}

// seedCollection inserts seed documents idempotently. The unique index on the
// seed identity turns repeated initialization (pod restarts, multiple
// replicas) into a no-op instead of duplicating the data; every process
// inserts only after its own index creation succeeded, so duplicates cannot
// slip in between. See https://github.com/delimitrou/DeathStarBench/pull/359.
func seedCollection(c *mongo.Collection, key bson.D, docs []interface{}) error {
	idx := mongo.IndexModel{Keys: key, Options: options.Index().SetUnique(true)}
	if _, err := c.Indexes().CreateOne(context.TODO(), idx); err != nil {
		return err
	}
	_, err := c.InsertMany(context.TODO(), docs, options.InsertMany().SetOrdered(false))
	if err != nil && !mongo.IsDuplicateKeyError(err) {
		return err
	}
	return nil
}
