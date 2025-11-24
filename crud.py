from typing import List, Optional
from sqlmodel import SQLModel, Field, Session, select, func
from datetime import datetime
import datetime as dt
from uuid import UUID, uuid4


# SQLModel Product Table
class Product(SQLModel, table=True):
    __tablename__ = "products"
    
    id: Optional[UUID] = Field(default_factory=uuid4, primary_key=True)
    name: str = Field(min_length=1, max_length=200, description="Product name", index=True)
    description: Optional[str] = Field(default=None, max_length=1000, description="Product description")
    price: float = Field(gt=0, description="Product price (must be greater than 0)", index=True)
    category: str = Field(min_length=1, max_length=100, description="Product category", index=True)
    stock: int = Field(ge=0, description="Stock quantity (must be >= 0)", default=0)
    sku: Optional[str] = Field(default=None, max_length=50, description="Stock Keeping Unit", unique=True, index=True)
    created_at: datetime = Field(default_factory=datetime.now(dt.timezone.utc))
    updated_at: datetime = Field(default_factory=datetime.now(dt.timezone.utc))


# Pydantic Models for API (Request/Response)
class ProductBase(SQLModel):
    name: str = Field(min_length=1, max_length=200, description="Product name")
    description: Optional[str] = Field(default=None, max_length=1000, description="Product description")
    price: float = Field(gt=0, description="Product price (must be greater than 0)")
    category: str = Field(min_length=1, max_length=100, description="Product category")
    stock: int = Field(ge=0, description="Stock quantity (must be >= 0)", default=0)
    sku: Optional[str] = Field(default=None, max_length=50, description="Stock Keeping Unit")


class ProductCreate(ProductBase):
    pass


class ProductUpdate(SQLModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    description: Optional[str] = Field(default=None, max_length=1000)
    price: Optional[float] = Field(default=None, gt=0)
    category: Optional[str] = Field(default=None, min_length=1, max_length=100)
    stock: Optional[int] = Field(default=None, ge=0)
    sku: Optional[str] = Field(default=None, max_length=50)


class ProductRead(ProductBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        json_schema_extra = {
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "name": "Laptop",
                "description": "High-performance laptop",
                "price": 999.99,
                "category": "Electronics",
                "stock": 50,
                "sku": "LAP-001",
                "created_at": "2024-01-01T00:00:00",
                "updated_at": "2024-01-01T00:00:00"
            }
        }


# CRUD Operations
class ProductCRUD:
    
    @staticmethod
    def filter_products(session: Session, filters: List, skip: int = 0, limit: int = 100) -> List[Product]:
        """Filter products by filters"""
        statement = select(Product).where(*filters).offset(skip).limit(limit)
        results = session.exec(statement)
        return list(results.all())

    @staticmethod
    def create(session: Session, product: ProductCreate) -> Product:
        """Create a new product"""
        db_product = Product(**product.model_dump())
        db_product.created_at = datetime.now(dt.timezone.utc)
        db_product.updated_at = datetime.now(dt.timezone.utc)
        
        session.add(db_product)
        session.commit()
        session.refresh(db_product)
        return db_product

    @staticmethod
    def get_by_id(session: Session, product_id: UUID) -> Optional[Product]:
        """Get a product by ID"""
        return session.get(Product, product_id)

    @staticmethod
    def get_all(session: Session, skip: int = 0, limit: int = 100) -> List[Product]:
        """Get all products with pagination"""
        statement = select(Product).offset(skip).limit(limit)
        results = session.exec(statement)
        return list(results.all())

    @staticmethod
    def get_by_category(session: Session, category: str, skip: int = 0, limit: int = 100) -> List[Product]:
        """Get products by category"""
        statement = (
            select(Product)
            .where(Product.category.ilike(f"%{category}%"))
            .offset(skip)
            .limit(limit)
        )
        results = session.exec(statement)
        return list(results.all())

    @staticmethod
    def search(session: Session, category: str, skip: int = 0, limit: int = 100) -> List[Product]:
        """Search products by name or description"""
        search_term = f"%{category}%"
        statement = (
            select(Product)
            .where(
                (Product.category.contains(search_term))
            )
            .offset(skip)
            .limit(limit)
        )
        results = session.exec(statement)
        return list(results.all())

    @staticmethod
    def update(session: Session, product_id: UUID, product_update: ProductUpdate) -> Optional[Product]:
        """Update a product"""
        db_product = session.get(Product, product_id)
        if not db_product:
            return None
        
        update_data = product_update.model_dump(exclude_unset=True)
        if not update_data:
            return db_product
        
        for field, value in update_data.items():
            setattr(db_product, field, value)
        
        db_product.updated_at = datetime.utcnow()
        session.add(db_product)
        session.commit()
        session.refresh(db_product)
        return db_product

    @staticmethod
    def delete(session: Session, product_id: UUID) -> bool:
        """Delete a product"""
        db_product = session.get(Product, product_id)
        if not db_product:
            return False
        
        session.delete(db_product)
        session.commit()
        return True

    @staticmethod
    def count(session: Session) -> int:
        """Get total number of products"""
        statement = select(func.count(Product.id))
        result = session.exec(statement)
        return result.one()

    @staticmethod
    def update_stock(session: Session, product_id: UUID, quantity: int) -> Optional[Product]:
        """Update product stock quantity"""
        db_product = session.get(Product, product_id)
        if not db_product:
            return None
        
        db_product.stock = max(0, db_product.stock + quantity)  # Prevent negative stock
        db_product.updated_at = datetime.utcnow()
        session.add(db_product)
        session.commit()
        session.refresh(db_product)
        return db_product

    @staticmethod
    def get_by_sku(session: Session, sku: str) -> Optional[Product]:
        """Get a product by SKU"""
        statement = select(Product).where(Product.sku == sku)
        result = session.exec(statement)
        return result.first()
