from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # Database Configuration
    DATABASE_URL: str = "sqlite:///./products.db"
    DB_ECHO: bool = True
    
    # API Settings
    API_TITLE: str = "Product Catalog API"
    API_VERSION: str = "1.0.0"
    
    # Pagination Defaults
    DEFAULT_SKIP: int = 0
    DEFAULT_LIMIT: int = 100
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


# Create a singleton instance
settings = Settings()

