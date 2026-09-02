package main

import (
	"context"
	"crypto/sha256"
	"fmt"
	"strconv"

	"github.com/rs/zerolog/log"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type User struct {
	Username string `bson:"username"`
	Password string `bson:"password"`
}

func initializeDatabase(url string) (*mongo.Client, func()) {
	log.Info().Msg("Generating test data...")

	newUsers := []interface{}{}

	for i := 0; i <= 500; i++ {
		suffix := strconv.Itoa(i)

		password := ""
		for j := 0; j < 10; j++ {
			password += suffix
		}
		sum := sha256.Sum256([]byte(password))

		newUsers = append(newUsers, User{
			fmt.Sprintf("Cornell_%x", suffix),
			fmt.Sprintf("%x", sum),
		})
	}

	uri := fmt.Sprintf("mongodb://%s", url)
	log.Info().Msgf("Attempting connection to %v", uri)

	opts := options.Client().ApplyURI(uri)
	client, err := mongo.Connect(context.TODO(), opts)
	if err != nil {
		log.Panic().Msg(err.Error())
	}
	log.Info().Msg("Successfully connected to MongoDB")

	collection := client.Database("user-db").Collection("user")
	err = seedCollection(collection, bson.D{{"username", 1}}, newUsers)
	if err != nil {
		log.Fatal().Msg(err.Error())
	}
	log.Info().Msg("Successfully inserted test data into user DB")

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
