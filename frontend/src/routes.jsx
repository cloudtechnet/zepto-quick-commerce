import Home from "./pages/Home/Home";
import Login from "./pages/Login/Login";
import Register from "./pages/Register/Register";
import Products from "./pages/Products/Products";
import ProductDetails from "./pages/ProductDetails/ProductDetails";
import Cart from "./pages/Cart/Cart";
import Checkout from "./pages/Checkout/Checkout";
import Orders from "./pages/Orders/Orders";
import Profile from "./pages/Profile/Profile";
import NotFound from "./pages/NotFound/NotFound";

const routes = [
  {
    path: "/",
    element: <Home />
  },
  {
    path: "/login",
    element: <Login />
  },
  {
    path: "/register",
    element: <Register />
  },
  {
    path: "/products",
    element: <Products />
  },
  {
    path: "/products/:id",
    element: <ProductDetails />
  },
  {
    path: "/cart",
    element: <Cart />
  },
  {
    path: "/checkout",
    element: <Checkout />
  },
  {
    path: "/orders",
    element: <Orders />
  },
  {
    path: "/profile",
    element: <Profile />
  },
  {
    path: "*",
    element: <NotFound />
  }
];

export default routes;