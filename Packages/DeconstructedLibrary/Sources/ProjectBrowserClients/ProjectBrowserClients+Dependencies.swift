import ComposableArchitecture

public extension DependencyValues {
	var assetDiscoveryClient: AssetDiscoveryClient {
		get { self[AssetDiscoveryClient.self] }
		set { self[AssetDiscoveryClient.self] = newValue }
	}

	var fileOperationsClient: FileOperationsClient {
		get { self[FileOperationsClient.self] }
		set { self[FileOperationsClient.self] = newValue }
	}

	var fileWatcherClient: FileWatcherClient {
		get { self[FileWatcherClient.self] }
		set { self[FileWatcherClient.self] = newValue }
	}

	var thumbnailClient: ThumbnailClient {
		get { self[ThumbnailClient.self] }
		set { self[ThumbnailClient.self] = newValue }
	}
}
