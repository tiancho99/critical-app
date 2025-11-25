from fastapi import FastAPI, Depends, HTTPException, status, Query, APIRouter
from sqlmodel import Session
from typing import List
from contextlib import asynccontextmanager
from uuid import UUID

from crud import ProductCRUD, ProductCreate, ProductUpdate, ProductRead, Product
from database import get_session, create_db_and_tables
from config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables on startup"""
    create_db_and_tables()
    yield


app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    lifespan=lifespan
)
router = APIRouter()

@router.get("/")
def root():
    return {"status": "Welcome to the Product Catalog API"}

@router.get("/health")
def health_check():
    return {"status": "OK"}


@router.post("/products", response_model=ProductRead, status_code=status.HTTP_201_CREATED)
def create_product(product: ProductCreate, session: Session = Depends(get_session)):
    """Create a new product"""
    return ProductCRUD.create(session, product)


@router.get("/products", response_model=List[ProductRead])
def get_products(
    name: str = Query(default=None, description="Name of the product"),
    description: str = Query(default=None, description="Description of the product"),
    price: float = Query(default=None, description="Price of the product"),
    category: str = Query(default=None, description="Category of the product"),
    stock: int = Query(default=None, description="Stock of the product"),
    sku: str = Query(default=None, description="SKU of the product"),
    skip: int = settings.DEFAULT_SKIP,
    limit: int = settings.DEFAULT_LIMIT,
    session: Session = Depends(get_session)
):
    filters = []
    if name:
        filters.append(Product.name.contains(name))
    if description:
        filters.append(Product.description.contains(description))
    if price:
        filters.append(Product.price == price)
    if category:
        filters.append(Product.category.contains(category))
    if stock:
        filters.append(Product.stock == stock)
    if sku:
        filters.append(Product.sku.contains(sku))
    """Get all products with pagination"""
    return ProductCRUD.filter_products(session, filters, skip=skip, limit=limit)


@router.get("/products/{product_id}", response_model=ProductRead)
def get_product(product_id: UUID, session: Session = Depends(get_session)):
    """Get a product by ID"""
    product = ProductCRUD.get_by_id(session, product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id {product_id} not found"
        )
    return product


@router.put("/products/{product_id}", response_model=ProductRead)
def update_product(
    product_id: UUID,
    product_update: ProductUpdate,
    session: Session = Depends(get_session)
):
    """Update a product"""
    product = ProductCRUD.update(session, product_id, product_update)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id {product_id} not found"
        )
    return product


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(product_id: UUID, session: Session = Depends(get_session)):
    """Delete a product"""
    success = ProductCRUD.delete(session, product_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id {product_id} not found"
        )
    return None


app.include_router(router, prefix="/api/v1")