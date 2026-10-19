/// Aread EPUB Backend Core Library.
library;

// Core & Constants
export 'src/core/constants/app_constants.dart';
export 'src/core/constants/asset_constants.dart';
export 'src/core/constants/ui_constants.dart';
export 'src/core/errors/exceptions.dart';
export 'src/core/errors/failures.dart';
export 'src/core/utils/hash_utils.dart';
export 'src/core/utils/path_utils.dart';
export 'src/core/utils/xml_utils.dart';

// Domain Entities & Sources
export 'src/domain/entities/accessibility_metadata.dart';
export 'src/domain/entities/annotation.dart';
export 'src/domain/entities/bookmark.dart';
export 'src/domain/entities/collection_info.dart';
export 'src/domain/entities/contributor.dart';
export 'src/domain/entities/derived_statistics.dart';
export 'src/domain/entities/locator.dart';
export 'src/domain/entities/manifest_resource.dart';
export 'src/domain/entities/nav_item.dart';
export 'src/domain/entities/publication.dart';
export 'src/domain/entities/publication_metadata.dart';
export 'src/domain/entities/reader_preferences.dart';
export 'src/domain/entities/reading_progress.dart';
export 'src/domain/entities/rendition_information.dart';
export 'src/domain/entities/search_match.dart';
export 'src/domain/entities/spine_item.dart';
export 'src/domain/entities/table_of_contents.dart';
export 'src/domain/entities/selected_text_model.dart';
export 'src/domain/entities/epub_view_chapter.dart';
export 'src/domain/source/book_source.dart';
export 'src/domain/validation/epub_validator.dart';

// Domain Engine & Security
export 'src/domain/engine/compatibility_report.dart';
export 'src/domain/engine/i_reader_engine.dart';
export 'src/domain/security/webview_security_policy.dart';

// Protection / DRM
export 'src/domain/protection/content_protection.dart';
export 'src/domain/protection/drm_state.dart';
export 'src/domain/protection/protection_rights.dart';

// Domain Repositories
export 'src/domain/repositories/i_annotation_repository.dart';
export 'src/domain/repositories/i_publication_repository.dart';
export 'src/domain/repositories/i_reader_preferences_repository.dart';
export 'src/domain/repositories/i_reading_progress_repository.dart';

// Domain Services
export 'src/domain/services/i_publication_parser.dart';
export 'src/domain/services/i_resource_resolver.dart';
export 'src/domain/services/i_search_service.dart';

// Data Implementations & Multi-Engine Architecture
export 'src/data/container/ocf_container.dart';
export 'src/data/database/app_database.dart';
export 'src/data/database/offline_sync_manager.dart';
export 'src/data/database/sync_journal.dart';
export 'src/data/engine/epub_compatibility_harness.dart';
export 'src/data/engine/pure_flutter_reader_engine.dart';
export 'src/data/engine/webview_epubjs_reader_engine.dart';
export 'src/data/parsers/container_xml_parser.dart';
export 'src/data/parsers/epub_document.dart';
export 'src/data/parsers/epub_cfi_parser.dart';
export 'src/data/parsers/epub_cfi_reader.dart';
export 'src/data/parsers/epub_parser.dart';
export 'src/data/parsers/epub_view_parser.dart';
export 'src/data/parsers/navigation_parser.dart';
export 'src/data/parsers/package_opf_parser.dart';
export 'src/data/protection/plain_protection_provider.dart';
export 'src/data/repositories/in_memory_annotation_repository.dart';
export 'src/data/repositories/in_memory_publication_repository.dart';
export 'src/data/repositories/in_memory_reader_preferences_repository.dart';
export 'src/data/repositories/in_memory_reading_progress_repository.dart';
export 'src/data/repositories/sqlite_annotation_repository.dart';
export 'src/data/repositories/sqlite_publication_repository.dart';
export 'src/data/repositories/sqlite_reader_preferences_repository.dart';
export 'src/data/repositories/sqlite_reading_progress_repository.dart';
export 'src/data/resolvers/publication_resource_resolver.dart';
export 'src/data/search/epub_search_service.dart';

// Application Layer
export 'src/application/commands/reader_command.dart';
export 'src/application/importer/book_importer.dart';
export 'src/application/navigator/locator_position_manager.dart';
export 'src/application/navigator/position_restoration_strategy.dart';
export 'src/application/session/reading_session.dart';
export 'src/application/state/reader_state.dart';
export 'src/application/usecases/manage_annotations_usecase.dart';
export 'src/application/usecases/navigate_usecase.dart';
export 'src/application/usecases/open_publication_usecase.dart';
export 'src/application/usecases/search_publication_usecase.dart';
export 'src/application/usecases/update_preferences_usecase.dart';
