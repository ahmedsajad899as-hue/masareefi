from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # App
    APP_NAME: str = "Masareefi"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ALLOWED_ORIGINS: str = (
        "http://localhost,"
        "http://localhost:8000,"
        "http://localhost:8080,"
        "http://localhost:8081,"
        "http://localhost:5000,"
        "http://localhost:5500,"
        "http://127.0.0.1,"
        "http://127.0.0.1:8000,"
        "http://127.0.0.1:8080,"
        "http://127.0.0.1:8081,"
        "http://192.168.68.120,"
        "http://192.168.68.120:8000,"
        "http://192.168.68.120:8080,"
        "http://192.168.68.120:8081"
    )

    # Database
    DATABASE_URL: str

    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # OpenAI
    OPENAI_API_KEY: str

    @property
    def origins_list(self) -> list[str]:
        if self.ALLOWED_ORIGINS.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]


settings = Settings()
