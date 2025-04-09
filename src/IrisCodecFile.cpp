#include <assert.h>
#include <iostream>
#include <filesystem>
#include <system_error>
#include "IrisCodecPriv.hpp"

// For Emscripten
#include <emscripten.h>
#include <unistd.h>

namespace IrisCodec {
inline void         GENERATE_TEMP_FILE          (File& file);
inline size_t       GET_FILE_SIZE               (File& file);
inline void         PERFORM_FILE_MAPPING        (File& file);
inline size_t       RESIZE_FILE                 (File& file, size_t bytes);
inline bool         LOCK_FILE                   (File& file, bool exclusive, bool wait);
inline void         UNLOCK_FILE                 (File& file);

// For Emscripten, use a fixed page size
const size_t IRIS_PAGE_SIZE = 16384; // Use Emscripten's page size

inline void GENERATE_TEMP_FILE(File& file) {
    // Emscripten implementation
    // Create a simple in-memory file
    std::string temp_path = "memory://temp_file";
    // Create a non-const copy to assign
    std::string& path_ref = const_cast<std::string&>(file->path);
    path_ref = temp_path;
    
    file->handle = tmpfile();
    if (!file->handle) {
        throw std::system_error(errno, std::generic_category(),
            "Failed to create temporary file in memory");
    }
}

inline size_t GET_FILE_SIZE(File& file) {
    auto& handle = file->handle;
    int result = -1;

    // If no handle provided, return
    if (handle == NULL)
        throw std::system_error(errno, std::generic_category(),
            "Cannot determine file size. Invalid file handle");

    // Seek the end of the file.
    result = fseek(handle, 0L, SEEK_END);
    if (result == -1)
        throw std::system_error(errno, std::generic_category(),
            "Cannot determine file size. Failed to seek file end");

    // Get the file size
    size_t size = ftell(handle);

    result = fseek(handle, 0L, SEEK_SET);
    if (result == -1)
        throw std::system_error(errno, std::generic_category(),
            "Failed to return to file start during file size determination");

    file->size = size;
    return size;
}

inline void PERFORM_FILE_MAPPING(File& file) {
    // For Emscripten, use a simple memory buffer
    file->ptr = static_cast<BYTE*>(malloc(file->size));
    if (!file->ptr) {
        throw std::system_error(errno, std::generic_category(),
            "Failed to allocate memory for file mapping");
    }

    // Read the file into memory
    fseek(file->handle, 0, SEEK_SET);
    size_t read_size = fread(file->ptr, 1, file->size, file->handle);
    if (read_size != file->size) {
        throw std::system_error(errno, std::generic_category(),
            "Failed to read file into memory");
    }
}

inline size_t RESIZE_FILE(File& file, size_t bytes) {
    auto& ptr = file->ptr;
    auto& size = file->size;

    // Return if no change needed
    if (size == bytes) return size;

    // Resize the file using Emscripten's file system
    int fd = fileno(file->handle);
    int result = ftruncate(fd, bytes);
    if (result == -1)
        throw std::system_error(errno, std::generic_category(),
            "Failed to resize file");

    // If we are expanding the file, write a byte to trigger
    // the OS to recognize the new file size.
    if (bytes > size) {
        fseek(file->handle, 0L, SEEK_END);
        fwrite("", sizeof(char), 1, file->handle);
        fseek(file->handle, 0L, SEEK_SET);
    }

    // If the file is already mapped, we must update the mapping.
    if (ptr) {
        // Reallocate the memory
        BYTE* new_ptr = static_cast<BYTE*>(realloc(ptr, bytes));
        if (!new_ptr) {
            throw std::system_error(errno, std::generic_category(),
                "Failed to reallocate memory for file mapping");
        }
        file->ptr = new_ptr;
    }

    size = bytes;
    return bytes;
}

inline bool LOCK_FILE(File& file, bool exclusive, bool wait) {
    // Emscripten doesn't support file locking
    // Just return true for now
    return true;
}

inline void UNLOCK_FILE(File& file) {
    // Emscripten doesn't support file locking
    // No-op
}

inline void UNMAP_FILE(BYTE*& ptr, size_t bytes) {
    if (ptr) {
        free(ptr);
        ptr = nullptr;
    }
}

// Keep the original __INTERNAL__File implementation from the codebase
__INTERNAL__File::__INTERNAL__File(const FileOpenInfo& info) :
    path(info.filePath),
    writeAccess(info.writeAccess)
{
}

__INTERNAL__File::__INTERNAL__File(const FileCreateInfo& info) :
    path(info.filePath),
    writeAccess(true)
{
}

__INTERNAL__File::__INTERNAL__File(const CacheCreateInfo& info)
{
}

__INTERNAL__File::~__INTERNAL__File()
{
    // For Emscripten, just free the memory
    if (ptr) {
        free(ptr);
        ptr = nullptr;
    }
    
    // Close the file
    if (handle) fclose(handle);
}

File create_file(const struct FileCreateInfo &create_info)
{
    try {
        File file = std::make_shared<__INTERNAL__File>(create_info);
        
        if (create_info.initial_size == 0)
            throw std::runtime_error("There must be an initial file size to map");
        
        // Create a file for reading and writing in binary format.
        file->handle = fopen(file->path.data(), "wb+");
        if (!file->handle)
            throw std::runtime_error("Failed to create the file");
        
        // Size the initial file in memory
        RESIZE_FILE(file, create_info.initial_size);
        
        // Map the file into memory
        PERFORM_FILE_MAPPING(file);
        
        // Return the newly mapped file
        return file;
        
    } catch (std::system_error &e) {
        std::cerr << "Failed to create file"
                  << create_info.filePath << ": "
                  << e.what() << " - "
                  << e.code().message() << "\n";
        return NULL;
    } catch (std::runtime_error &e) {
        std::cerr << "Failed to create file"
                  << create_info.filePath << ": "
                  << e.what() << "\n";
        return NULL;
    }   return NULL;
}

/// Open a file for read or read-write access.
File open_file(const struct FileOpenInfo &open_info)
{
    try {
        File file = std::make_shared<__INTERNAL__File>(open_info);

        // Open the file for reading or reading and writing depending on write access
        file->handle = fopen(file->path.data(), open_info.writeAccess ? "rb+" : "rb");
        if (!file->handle)
            throw std::runtime_error("Failed to open the file");

        // Get the file size.
        GET_FILE_SIZE(file);
        
        // Map the file into memory
        PERFORM_FILE_MAPPING(file);
        
        // Return the newly mapped file
        return file;
        
    } catch (std::system_error &e) {
        std::cerr << "Failed to open file"
                  << open_info.filePath << ": "
                  << e.what() << " - "
                  << e.code().message() << "\n";
        
        // Return a nullptr
        return NULL;
    } catch (std::runtime_error &e) {
        std::cerr << "Failed to open file"
                  << open_info.filePath << ": "
                  << e.what() << "\n";
        return NULL;
    }   return NULL;
}

/// Create a new file-system temporary file for temporary archiving of slide data to disk.
File create_cache_file(const struct CacheCreateInfo &create_info)
{
    try {
        File file = std::make_shared<__INTERNAL__File>(create_info);
        
        // Generate the unlinked and unique temporary cache file.
        GENERATE_TEMP_FILE(file);
        
        // Set the initial cache file to about 500 MB at the page break.
        RESIZE_FILE(file, ((size_t)5E8&~(IRIS_PAGE_SIZE-1))+IRIS_PAGE_SIZE);

        // Map the file into memory
        PERFORM_FILE_MAPPING(file);
        
        // Return the new cache file
        return file;
        
    } catch (std::system_error &e) {
        std::cerr << "Failed to create an cache file: "
                  << e.what() << " - "
                  << e.code().message() << "\n";
        
        // Return a nullptr
        return NULL;
    } catch (std::runtime_error &e) {
        std::cerr << "Failed to create file: "
                  << e.what() << "\n";
        return NULL;
    }   return NULL;
}

Result resize_file(const File &file, const struct FileResizeInfo &info)
{
    // Check if page alignment was requested
    auto size = info.pageAlign ?
    // if page align, drop the size to the closest page break
    // and then add one page tobe at least the request size
    (info.size & ~(IRIS_PAGE_SIZE-1)) + IRIS_PAGE_SIZE :
    // Else, just do the info.size
    info.size;
    
    try {
        // Need to remove const qualifier to call RESIZE_FILE
        RESIZE_FILE(const_cast<File&>(file), size);
        return IRIS_SUCCESS;
    } catch (std::system_error&e) {
        return {
            IRIS_FAILURE,
            e.what()
        };
    } return IRIS_FAILURE;
}
} // END IRIS CODEC NAMESPACE
