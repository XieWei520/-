package message

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"reflect"
	"testing"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/stretchr/testify/assert"
)

type fakeMessageBackupSnapshotDB struct {
	inserted    *MessageBackupSnapshot
	insertErr   error
	queryByID   *MessageBackupSnapshot
	queryByIDID int64
	insertedID  int64
	latest      *MessageBackupSnapshot
}

func (f *fakeMessageBackupSnapshotDB) InsertMessageBackupSnapshot(snapshot *MessageBackupSnapshot) (int64, error) {
	if f.insertErr != nil {
		return 0, f.insertErr
	}
	copied := *snapshot
	f.inserted = &copied
	if f.insertedID == 0 {
		f.insertedID = 1
	}
	if f.queryByID == nil {
		f.queryByID = &copied
		f.queryByID.Id = f.insertedID
	}
	return f.insertedID, nil
}

func (f *fakeMessageBackupSnapshotDB) QueryMessageBackupSnapshotByID(id int64) (*MessageBackupSnapshot, error) {
	f.queryByIDID = id
	if f.queryByID == nil {
		return nil, nil
	}
	copied := *f.queryByID
	return &copied, nil
}

func (f *fakeMessageBackupSnapshotDB) QueryLatestMessageBackupSnapshot(uid string) (*MessageBackupSnapshot, error) {
	if f.latest == nil {
		return nil, nil
	}
	copied := *f.latest
	return &copied, nil
}

type fakeMessageBackupFileService struct {
	uploadedPath string
	contentType  string
	payload      []byte
	returnedPath string
	uploadResult map[string]interface{}
	readPath     string
	readReader   io.ReadCloser
	readType     string
	readErr      error
}

func (f *fakeMessageBackupFileService) UploadFile(filePath string, contentType string, copyFileWriter func(io.Writer) error) (map[string]interface{}, error) {
	var payload bytes.Buffer
	err := copyFileWriter(&payload)
	if err != nil {
		return nil, err
	}

	f.uploadedPath = filePath
	f.contentType = contentType
	f.payload = append([]byte(nil), payload.Bytes()...)
	if f.uploadResult != nil {
		return f.uploadResult, nil
	}
	return map[string]interface{}{
		"path": f.returnedPath,
	}, nil
}

func (f *fakeMessageBackupFileService) DownloadAndMakeCompose(uploadPath string, downloadURLs []string) (map[string]interface{}, error) {
	panic("unexpected call")
}

func (f *fakeMessageBackupFileService) DownloadURL(path string, filename string) (string, error) {
	panic("unexpected call")
}

func (f *fakeMessageBackupFileService) DownloadImage(url string, ctx context.Context) (io.ReadCloser, error) {
	panic("unexpected call")
}

func (f *fakeMessageBackupFileService) InitiateMultipartUpload(filePath string, contentType string, fileSize int64, chunkSize int64) (map[string]interface{}, error) {
	panic("unexpected call")
}

func (f *fakeMessageBackupFileService) UploadMultipartPart(filePath string, uploadID string, partNumber int, reader io.Reader) error {
	panic("unexpected call")
}

func (f *fakeMessageBackupFileService) CompleteMultipartUpload(filePath string, contentType string, uploadID string, parts []int) (map[string]interface{}, error) {
	panic("unexpected call")
}

func (f *fakeMessageBackupFileService) AbortMultipartUpload(uploadID string) error {
	return nil
}

func (f *fakeMessageBackupFileService) ReadFile(path string, ctx context.Context) (io.ReadCloser, string, error) {
	f.readPath = path
	if f.readErr != nil {
		return nil, "", f.readErr
	}
	if f.readReader == nil {
		return io.NopCloser(bytes.NewReader(nil)), f.readType, nil
	}
	return f.readReader, f.readType, nil
}

func TestMessageBackupSnapshotUsesStringTimestamps(t *testing.T) {
	snapshotType := reflect.TypeOf(MessageBackupSnapshot{})

	createdAt, ok := snapshotType.FieldByName("CreatedAt")
	assert.True(t, ok)
	assert.Equal(t, reflect.String, createdAt.Type.Kind())

	updatedAt, ok := snapshotType.FieldByName("UpdatedAt")
	assert.True(t, ok)
	assert.Equal(t, reflect.String, updatedAt.Type.Kind())
}

func TestMinioMessageBackupStoreSaveUsesUploadedObjectPath(t *testing.T) {
	payload := []byte(`{"schema_version":2,"messages":[{"message_id":"m1"}]}`)
	fileService := &fakeMessageBackupFileService{
		returnedPath: "message-backup/10000/stored-u_demo.json",
	}
	db := &fakeMessageBackupSnapshotDB{
		insertedID: 42,
		queryByID: &MessageBackupSnapshot{
			Id:        42,
			Uid:       testutil.UID,
			FileName:  "u_demo.json",
			ObjectKey: "message-backup/10000/stored-u_demo.json",
			CreatedAt: "2026-04-13 10:00:00",
			UpdatedAt: "2026-04-13 10:00:00",
		},
	}
	store := &minioMessageBackupStore{
		db:          db,
		fileService: fileService,
		now: func() time.Time {
			return time.Unix(1713000000, 123)
		},
	}

	snapshot, err := store.Save(testutil.UID, "u_demo.json", payload)
	assert.NoError(t, err)
	if assert.NotNil(t, snapshot) {
		assert.Equal(t, fileService.returnedPath, snapshot.ObjectKey)
		assert.Equal(t, int64(42), snapshot.Id)
	}
	if assert.NotNil(t, db.inserted) {
		assert.Equal(t, fileService.returnedPath, db.inserted.ObjectKey)
		assert.Equal(t, testutil.UID, db.inserted.Uid)
		assert.Equal(t, "u_demo.json", db.inserted.FileName)
	}
	assert.Equal(t, int64(42), db.queryByIDID)
	assert.Equal(t, "application/json", fileService.contentType)
	assert.Equal(t, payload, fileService.payload)
	assert.Contains(t, fileService.uploadedPath, "message-backup/"+testutil.UID+"/")
}

func TestMinioMessageBackupStoreSavePrefixesMessageBackupBucketForBareKeys(t *testing.T) {
	payload := []byte(`{"schema_version":2,"messages":[{"message_id":"m1"}]}`)
	fileService := &fakeMessageBackupFileService{
		returnedPath: "10000/stored-u_demo.json",
	}
	db := &fakeMessageBackupSnapshotDB{
		insertedID: 43,
		queryByID: &MessageBackupSnapshot{
			Id:        43,
			Uid:       testutil.UID,
			FileName:  "u_demo.json",
			ObjectKey: "message-backup/10000/stored-u_demo.json",
			CreatedAt: "2026-04-13 10:00:00",
			UpdatedAt: "2026-04-13 10:00:00",
		},
	}
	store := &minioMessageBackupStore{
		db:          db,
		fileService: fileService,
		now: func() time.Time {
			return time.Unix(1713000000, 123)
		},
	}

	snapshot, err := store.Save(testutil.UID, "u_demo.json", payload)
	assert.NoError(t, err)
	if assert.NotNil(t, snapshot) {
		assert.Equal(t, "message-backup/10000/stored-u_demo.json", snapshot.ObjectKey)
		assert.Equal(t, int64(43), snapshot.Id)
	}
	if assert.NotNil(t, db.inserted) {
		assert.Equal(t, "message-backup/10000/stored-u_demo.json", db.inserted.ObjectKey)
	}
	assert.Contains(t, fileService.uploadedPath, "message-backup/"+testutil.UID+"/")
}

func TestMinioMessageBackupStoreLoadLatestPrefixesMessageBackupBucketForLegacyRows(t *testing.T) {
	fileService := &fakeMessageBackupFileService{
		readReader: io.NopCloser(bytes.NewReader([]byte(`[]`))),
		readType:   "application/json",
	}
	store := &minioMessageBackupStore{
		db: &fakeMessageBackupSnapshotDB{
			latest: &MessageBackupSnapshot{
				Id:        44,
				Uid:       testutil.UID,
				FileName:  "u_demo.json",
				ObjectKey: "10000/stored-u_demo.json",
			},
		},
		fileService: fileService,
	}

	snapshot, reader, contentType, err := store.LoadLatest(testutil.UID)
	assert.NoError(t, err)
	if assert.NotNil(t, snapshot) {
		assert.Equal(t, "10000/stored-u_demo.json", snapshot.ObjectKey)
	}
	assert.NotNil(t, reader)
	assert.Equal(t, "application/json", contentType)
	assert.Equal(t, "message-backup/10000/stored-u_demo.json", fileService.readPath)
	_ = reader.Close()
}

func TestMinioMessageBackupStoreSaveDeletesUploadWhenInsertFails(t *testing.T) {
	payload := []byte(`{"schema_version":2}`)
	fileService := &fakeMessageBackupFileService{
		returnedPath: "message-backup/10000/stored-u_demo.json",
	}
	db := &fakeMessageBackupSnapshotDB{
		insertErr: errors.New("insert failed"),
	}
	var cleanedPath string
	store := &minioMessageBackupStore{
		db:          db,
		fileService: fileService,
		now: func() time.Time {
			return time.Unix(1713000000, 123)
		},
		deleteObject: func(uploadPath string) error {
			cleanedPath = uploadPath
			return nil
		},
	}

	snapshot, err := store.Save(testutil.UID, "u_demo.json", payload)
	assert.Nil(t, snapshot)
	assert.EqualError(t, err, "insert failed")
	assert.Equal(t, fileService.uploadedPath, cleanedPath)
}

func TestMinioMessageBackupStoreSaveReturnsErrorWhenUploadPathMissing(t *testing.T) {
	payload := []byte(`{"schema_version":2}`)
	fileService := &fakeMessageBackupFileService{
		uploadResult: map[string]interface{}{},
	}
	db := &fakeMessageBackupSnapshotDB{}
	var cleanedPath string
	store := &minioMessageBackupStore{
		db:          db,
		fileService: fileService,
		now: func() time.Time {
			return time.Unix(1713000000, 123)
		},
		deleteObject: func(uploadPath string) error {
			cleanedPath = uploadPath
			return nil
		},
	}

	snapshot, err := store.Save(testutil.UID, "u_demo.json", payload)
	assert.Nil(t, snapshot)
	assert.ErrorIs(t, err, errMessageBackupUploadPathMissing)
	assert.Equal(t, fileService.uploadedPath, cleanedPath)
}

func TestMessageBackupMigrationMatchesContract(t *testing.T) {
	content, err := os.ReadFile("sql/message-20260413-01.sql")
	assert.NoError(t, err)
	assert.NotContains(t, string(content), "ON UPDATE CURRENT_TIMESTAMP")
}
